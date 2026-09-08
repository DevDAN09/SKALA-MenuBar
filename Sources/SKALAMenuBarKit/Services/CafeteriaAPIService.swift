import Foundation
import Cocoa
import Vision

public final class CafeteriaAPIService: @unchecked Sendable {
    private let session = URLSession.shared
    private let channelId = "_LCxlxlxb"
    private let cacheFileName = "cafeteria_weekly_menu_cache.json"

    public init() {}

    private struct PostMedia: Codable {
        let url: String?
        let large_url: String?
        let xlarge_url: String?
    }

    private struct PostItem: Codable {
        let id: Int
        let title: String?
        let published_at: Int64
        let media: [PostMedia]?
        let permalink: String?
    }

    private struct PostResponse: Codable {
        let items: [PostItem]
    }

    private struct OCRBox {
        let text: String
        let y: Double
    }

    public func fetchWeeklyMenu(forceRefresh: Bool = false) async throws -> WeeklyMenu {
        if !forceRefresh, let cached = loadFromCache() {
            if isDateInCurrentWeek(cached.fetchedAt) {
                return cached
            }
        }

        guard let postApiUrl = URL(string: "https://pf.kakao.com/rocket-web/web/profiles/\(channelId)/posts") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: postApiUrl)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let postResponse = try JSONDecoder().decode(PostResponse.self, from: data)
        let postWithMenu = postResponse.items.first(where: {
            let hasMedia = ($0.media?.count ?? 0) > 0
            let isMenuTitle = ($0.title?.contains("주간메뉴") == true) || ($0.title?.contains("식단") == true)
            return hasMedia && isMenuTitle
        }) ?? postResponse.items.first(where: { ($0.media?.count ?? 0) > 0 })

        guard let post = postWithMenu,
              let media = post.media?.first,
              let imageUrlStr = media.xlarge_url ?? media.large_url ?? media.url,
              let imageUrl = URL(string: imageUrlStr) else {
            throw NSError(domain: "CafeteriaAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "식단표 게시글을 찾을 수 없습니다."])
        }

        var imgRequest = URLRequest(url: imageUrl)
        imgRequest.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (imageData, _) = try await session.data(for: imgRequest)

        let weeklyMenu = try await parseWeeklyMenuFromImage(
            imageData: imageData,
            postTitle: post.title ?? "이노밸리 구내식당 주간메뉴",
            imageUrl: imageUrlStr,
            postUrl: post.permalink ?? "https://pf.kakao.com/\(channelId)"
        )

        saveToCache(weeklyMenu)
        return weeklyMenu
    }

    private func parseWeeklyMenuFromImage(
        imageData: Data,
        postTitle: String,
        imageUrl: String,
        postUrl: String
    ) async throws -> WeeklyMenu {
        guard let nsImage = NSImage(data: imageData),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "CafeteriaAPIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "식단표 이미지 로드 실패"])
        }

        let imgW = Double(cgImage.width)
        let imgH = Double(cgImage.height)
        let defaultColumnRanges: [(day: String, x1: Double, x2: Double)] = [
            ("월", 0.11, 0.26),
            ("화", 0.26, 0.41),
            ("수", 0.41, 0.56),
            ("목", 0.56, 0.71),
            ("금", 0.71, 0.86)
        ]

        var dailyMenus: [DailyMenu] = []

        for col in defaultColumnRanges {
            let cropRect = CGRect(
                x: CGFloat(imgW * col.x1),
                y: 0,
                width: CGFloat(imgW * (col.x2 - col.x1)),
                height: CGFloat(imgH)
            )

            guard let croppedImage = cgImage.cropping(to: cropRect) else { continue }
            let dayBoxes = try await runOCR(on: croppedImage)

            // Extract date if present
            let dateBox = dayBoxes.first { box in
                box.y < 0.15 && box.text.range(of: #"\d{2,4}[-./]\d{1,2}[-./]\d{1,2}"#, options: .regularExpression) != nil
            }
            let dateString = dateBox?.text ?? ""

            // 1. Breakfast: 0.115 <= y < 0.33
            let bKoreanItems = cleanItems(dayBoxes.filter { $0.y >= 0.115 && $0.y < 0.235 })
            let bTakeoutItems = cleanItems(dayBoxes.filter { $0.y >= 0.235 && $0.y < 0.33 })

            var breakfastCategories: [MealCategoryItem] = []
            if !bKoreanItems.isEmpty {
                breakfastCategories.append(MealCategoryItem(cornerName: "한식", items: bKoreanItems))
            }
            if !bTakeoutItems.isEmpty {
                breakfastCategories.append(MealCategoryItem(cornerName: "간편식/Take-out", items: bTakeoutItems))
            }

            // 2. Lunch: 0.33 <= y < 0.735
            let lKoreanItems = cleanItems(dayBoxes.filter { $0.y >= 0.33 && $0.y < 0.47 })
            let lWesternItems = cleanItems(dayBoxes.filter { $0.y >= 0.47 && $0.y < 0.58 })
            let lNoodleItems = cleanItems(dayBoxes.filter { $0.y >= 0.58 && $0.y < 0.68 })
            let lSaladItems = cleanItems(dayBoxes.filter { $0.y >= 0.68 && $0.y < 0.735 })

            var lunchCategories: [MealCategoryItem] = []
            if !lKoreanItems.isEmpty {
                lunchCategories.append(MealCategoryItem(cornerName: "한식 (Korean)", items: lKoreanItems))
            }
            if !lWesternItems.isEmpty {
                lunchCategories.append(MealCategoryItem(cornerName: "양식/일품 (Western)", items: lWesternItems))
            }
            if !lNoodleItems.isEmpty {
                lunchCategories.append(MealCategoryItem(cornerName: "면/특식 (Noodle)", items: lNoodleItems))
            }
            if !lSaladItems.isEmpty {
                lunchCategories.append(MealCategoryItem(cornerName: "샐러드바 & 디저트", items: lSaladItems))
            }

            // 3. Dinner: 0.735 <= y < 0.96
            let dMainItems = cleanItems(dayBoxes.filter { $0.y >= 0.735 && $0.y < 0.875 })
            let dTakeoutItems = cleanItems(dayBoxes.filter { $0.y >= 0.875 && $0.y < 0.96 })

            var dinnerCategories: [MealCategoryItem] = []
            if !dMainItems.isEmpty {
                dinnerCategories.append(MealCategoryItem(cornerName: "한식/일품", items: dMainItems))
            }
            if !dTakeoutItems.isEmpty {
                dinnerCategories.append(MealCategoryItem(cornerName: "Take-Out", items: dTakeoutItems))
            }

            dailyMenus.append(DailyMenu(
                weekday: col.day,
                dateString: dateString,
                breakfast: breakfastCategories,
                lunch: lunchCategories,
                dinner: dinnerCategories
            ))
        }

        return WeeklyMenu(
            title: postTitle,
            imageUrl: imageUrl,
            postUrl: postUrl,
            days: dailyMenus,
            fetchedAt: Date()
        )
    }

    private static let foodCustomWords: [String] = [
        "된장국", "미역국", "김치찌개", "비지찌개", "부대찌개", "갈비탕", "육개장", "황태해장국",
        "꽃게탕", "우동국물", "계란국", "어묵국", "새우젓국", "나가사끼짬뽕", "양송이스프", "스프",
        "흑미밥", "쌀밥", "현미밥", "보리밥", "볶음밥", "하이라이스", "카레", "덮밥",
        "불고기", "제육볶음", "돈불고기", "간장불고기", "안동찜닭", "돈까스", "치킨까스", "생선까스",
        "떡갈비", "너비아니", "오삼불고기", "고등어조림", "토마토스파게티", "춘권", "타코야끼", "어향가지덮밥",
        "두부조림", "잡채", "건파래자반", "오이생채", "단무지", "어묵볶음", "채어묵", "피망볶음", "브로콜리",
        "양배추쌈", "쌈장", "우엉조림", "무말랭이무침", "호박나물", "겉절이", "나박김치", "포기김치", "깍두기",
        "피클", "할라피뇨", "연유", "깻잎지", "풋고추", "그린빈", "맛살볶음", "파채너비아니구이",
        "샐러드", "샐러드바", "드레싱", "식빵튀김", "숭늉", "식혜", "매실차", "아이스티", "미숫가루", "요구르트",
        "샌드위치", "선식", "샐러드SET", "간편식", "멸치칼국수", "만두", "초간장", "불닭볶음밥", "알감자샐러드",
        "비빔밥", "콩나물밥", "계란찜", "궁중떡볶이", "새송이버섯볶음", "얼갈이겉절이", "닭강정", "돈육땅콩강정"
    ]

    private func runOCR(on cgImage: CGImage) async throws -> [OCRBox] {
        // 1. Contrast enhancement via CoreImage to clarify blurred Korean strokes in compressed JPEGs
        let ci = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ci, forKey: kCIInputImageKey)
        filter?.setValue(1.25, forKey: kCIInputContrastKey)
        filter?.setValue(0.04, forKey: kCIInputBrightnessKey)
        let ciCtx = CIContext()
        let enhancedImage = filter?.outputImage.flatMap { ciCtx.createCGImage($0, from: $0.extent) } ?? cgImage

        // 2. High-quality 3x upscale (ideal font height for Hangul syllable recognition)
        let scale: CGFloat = 3.0
        let newW = Int(CGFloat(enhancedImage.width) * scale)
        let newH = Int(CGFloat(enhancedImage.height) * scale)

        let scaledImage: CGImage
        if let ctx = CGContext(
            data: nil,
            width: newW,
            height: newH,
            bitsPerComponent: 8,
            bytesPerRow: newW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) {
            ctx.interpolationQuality = .high
            ctx.draw(enhancedImage, in: CGRect(x: 0, y: 0, width: newW, height: newH))
            scaledImage = ctx.makeImage() ?? enhancedImage
        } else {
            scaledImage = enhancedImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                var results: [OCRBox] = []
                for obs in observations {
                    if let top = obs.topCandidates(1).first {
                        let text = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty {
                            let bbox = obs.boundingBox
                            results.append(OCRBox(
                                text: text,
                                y: Double(1.0 - (bbox.origin.y + bbox.size.height))
                            ))
                        }
                    }
                }
                continuation.resume(returning: results)
            }
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.customWords = Self.foodCustomWords

            let handler = VNImageRequestHandler(cgImage: scaledImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func cleanItems(_ boxes: [OCRBox]) -> [String] {
        var items: [String] = []
        let sorted = boxes.sorted { $0.y < $1.y }

        for box in sorted {
            var t = box.text.trimmingCharacters(in: .whitespacesAndNewlines)

            // Filter out table headers, notices, dates, phone numbers
            if t.contains("메뉴는") || t.contains("사생상황") || t.contains("식자재") || t.contains("변경") || t.contains("사정")
                || t.contains("문의") || t.contains("연락") || t.contains("사장상") || t.contains("031-") || t.contains("합니다") {
                continue
            }
            if t == "화" || t == "수" || t == "목" || t == "금" || t == "월" || t == "목요일" || t == "금요일" || t == "화묘일" {
                continue
            }
            if t.range(of: #"^\d{2,4}[-./]"#, options: .regularExpression) != nil {
                continue
            }
            if t.range(of: #"^[•\.\s\-\_\~]+$"#, options: .regularExpression) != nil {
                continue
            }
            if t.count < 2 { continue }

            // Strip leading brackets/prefixes like "쌀뚝)", "덜뚝)", "(뚝)", "[뚝]"
            t = t.replacingOccurrences(of: #"^[가-힣\w\s]*\)\s*"#, with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"^[\"\'\.\,\!\?\[\]\•\·]+"#, with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"[\"\'\.\,\!\?\[\]\•\·]+$"#, with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"\([별빨].*$"#, with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"\s*[빨별]\)$"#, with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"\([빨별]$"#, with: "", options: .regularExpression)

            // Common optical & phonetic Korean food OCR corrections
            let corrections: [(String, String)] = [
                ("얼갈이된\\s*중국", "얼갈이된장국"),
                ("된\\s*중국", "된장국"),
                ("된작국", "된장국"),
                ("찌가", "찌개"),
                ("포기김지", "포기김치"),
                ("나박김지", "나박김치"),
                ("김지", "김치"),
                ("비트양배주피를", "비트양배추피클"),
                ("피를$", "피클"),
                ("숨늄", "숭늉"),
                ("숨늅", "숭늉"),
                ("숭늄", "숭늉"),
                ("양배추쌈&쌈정", "양배추쌈&쌈장"),
                ("쌈정$", "쌈장"),
                ("양배추쌈&쌈잠", "양배추쌈&쌈장"),
                ("쌈잠$", "쌈장"),
                ("양솔이", "양송이"),
                ("풀소스", "굴소스"),
                ("어니언림", "어니언링"),
                ("돈육땅콩강점", "돈육땅콩강정"),
                ("강점$", "강정"),
                ("우어조림", "우엉조림"),
                ("미\\s*역국", "미역국"),
                ("파재너비아니", "파채너비아니"),
                ("파채너비아니구[0-9O이]", "파채너비아니구이"),
                ("재어묵", "채어묵"),
                ("돈재피망", "돈채피망"),
                ("안돌찜닭", "안동찜닭"),
                ("그린비맛살볶을", "그린빈맛살볶음"),
                ("그린 빈맛살볶음", "그린빈맛살볶음"),
                ("비시씨가", "비지찌개"),
                ("비지찌가", "비지찌개"),
                ("새송이버서\\s*볶음", "새송이버섯볶음"),
                ("새송이버서", "새송이버섯"),
                ("옥수수본전", "옥수수전"),
                ("그 릭요거트", "그릭요거트"),
                ("깍두$", "깍두기"),
                ("모이생채", "오이생채"),
                ("초간작", "초간장"),
                ("양념작", "양념장"),
                ("타코야$", "타코야끼"),
                ("삼선 까스", "생선까스"),
                ("삼선까스", "생선까스"),
                ("타르 타르", "타르타르소스"),
                ("하이스소스", "하이라이스소스"),
                ("굴소스복을", "굴소스볶음"),
                ("떡갈비볶을", "떡갈비볶음")
            ]

            for (pattern, repl) in corrections {
                t = t.replacingOccurrences(of: pattern, with: repl, options: .regularExpression)
            }

            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.count >= 2 {
                items.append(t)
            }
        }
        return items
    }

    private var cacheFileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(cacheFileName)
    }

    private func loadFromCache() -> WeeklyMenu? {
        guard let url = cacheFileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WeeklyMenu.self, from: data)
    }

    private func saveToCache(_ menu: WeeklyMenu) {
        guard let url = cacheFileURL, let data = try? JSONEncoder().encode(menu) else { return }
        try? data.write(to: url)
    }

    private func isDateInCurrentWeek(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}
