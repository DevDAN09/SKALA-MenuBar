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

    private func runOCR(on cgImage: CGImage) async throws -> [OCRBox] {
        // Upscale 2x using high-quality interpolation to drastically boost OCR accuracy on dense Korean fonts
        let scale: CGFloat = 2.0
        let newW = Int(CGFloat(cgImage.width) * scale)
        let newH = Int(CGFloat(cgImage.height) * scale)

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
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: newW, height: newH))
            scaledImage = ctx.makeImage() ?? cgImage
        } else {
            scaledImage = cgImage
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
            var t = box.text
            t = t.replacingOccurrences(of: "^[\"'\']+", with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: "[\"'\']+$", with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"^\.{2,}"#, with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"[」』>.]+$"#, with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"\([별빨]$"#, with: "", options: .regularExpression)
            t = t.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "」』\"'.")))

            if t.count < 2 || t == "화" || t == "수" || t == "목" || t == "금" || t == "월" {
                continue
            }
            items.append(t)
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
