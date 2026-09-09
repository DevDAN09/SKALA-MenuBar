import SwiftUI

public struct CafeteriaMenuView: View {
    @ObservedObject var viewModel: CafeteriaViewModel

    public init(viewModel: CafeteriaViewModel) {
        self.viewModel = viewModel
    }

    private let weekdays = ["월", "화", "수", "목", "금"]

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🍱 이노밸리 구내식당")
                        .font(.headline)
                    if let menu = viewModel.weeklyMenu {
                        Text(menu.title)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            // Weekday Selector
            HStack(spacing: 4) {
                ForEach(weekdays, id: \.self) { day in
                    let isSelected = viewModel.selectedWeekday == day
                    let isToday = day == CafeteriaViewModel.calculateCurrentWeekday()

                    Button {
                        viewModel.selectedWeekday = day
                    } label: {
                        VStack(spacing: 2) {
                            Text(day)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            if isToday {
                                Circle()
                                    .fill(isSelected ? Color.white : Color.accentColor)
                                    .frame(width: 4, height: 4)
                            } else {
                                Spacer().frame(height: 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                        .foregroundColor(isSelected ? .white : .primary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Meal Type Tabs (중식, 석식)
            HStack(spacing: 6) {
                ForEach(MealType.allCases) { type in
                    let isSelected = viewModel.selectedMealType == type
                    Button {
                        viewModel.selectedMealType = type
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.system(size: 11))
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                        .foregroundColor(isSelected ? .white : .primary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Corner Selector (한식, 양식, 면)
            HStack(spacing: 6) {
                ForEach(MealCorner.allCases) { corner in
                    let isSelected = viewModel.selectedCorner == corner
                    Button {
                        viewModel.selectedCorner = corner
                    } label: {
                        HStack(spacing: 3) {
                            Text(corner.icon)
                                .font(.system(size: 11))
                            Text(corner.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(isSelected ? Color.secondary.opacity(0.24) : Color.secondary.opacity(0.08))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Operating Hours
            HStack {
                Label(viewModel.selectedMealType.operatingHours, systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if let dateStr = viewModel.currentDayMenu?.dateString, !dateStr.isEmpty {
                    Text(dateStr)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Menu Content List (유연한 스크롤 영역)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    if let dayMenu = viewModel.currentDayMenu {
                        let categories = dayMenu.meals(for: viewModel.selectedMealType)

                        if categories.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "fork.knife")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("등록된 식단 정보가 없습니다.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else if viewModel.selectedMealType == .lunch {
                            let matched = categories.filter { cat in
                                switch viewModel.selectedCorner {
                                case .korean:
                                    return cat.cornerName.contains("한식")
                                case .western:
                                    return cat.cornerName.contains("양식") || cat.cornerName.contains("일품")
                                case .noodle:
                                    return cat.cornerName.contains("면") || cat.cornerName.contains("특식")
                                }
                            }
                            let saladCategories = categories.filter { cat in
                                cat.cornerName.contains("샐러드") || cat.cornerName.contains("디저트")
                            }

                            if matched.isEmpty && saladCategories.isEmpty {
                                VStack(spacing: 8) {
                                    Text("해당 코너 식단 정보가 없습니다.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                            } else {
                                ForEach(matched) { category in
                                    cornerCard(category)
                                }
                                ForEach(saladCategories) { salad in
                                    saladCard(salad)
                                }
                            }
                        } else {
                            // 석식
                            if viewModel.selectedCorner != .korean {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 10))
                                    Text("석식은 '한식/일품' 코너로 운영됩니다.")
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                                .padding(.bottom, 2)
                            }

                            ForEach(categories) { category in
                                cornerCard(category)
                            }
                        }
                    } else if viewModel.isLoading {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("식단표 이미지 분석 중...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 6) {
                            Text("식단표를 불러오지 못했습니다.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Divider()

            // Action Buttons & Footer
            HStack {
                Button("식단표 원본") {
                    viewModel.openOriginalImage()
                }
                .font(.caption2)

                Button("카카오 채널") {
                    viewModel.openKakaoChannel()
                }
                .font(.caption2)

                Spacer()

                Button("새로고침") {
                    Task {
                        await viewModel.refresh(force: true)
                    }
                }
                .font(.caption2)
            }
        }
        .padding(14)
        .frame(width: 320)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func cornerCard(_ category: MealCategoryItem) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(iconForCorner(category.cornerName))
                    .font(.caption)
                Text(category.cornerName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                ForEach(category.items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 5) {
                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                        Text(item)
                            .font(.system(size: 12))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func saladCard(_ category: MealCategoryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("🥗")
                    .font(.caption)
                Text(category.cornerName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(category.items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 5) {
                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.system(size: 9))
                        Text(item)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }

    private func iconForCorner(_ name: String) -> String {
        if name.contains("한식") { return "🍚" }
        if name.contains("양식") || name.contains("일품") { return "🍳" }
        if name.contains("면") || name.contains("Noodle") { return "🍜" }
        if name.contains("샐러드") { return "🥗" }
        if name.contains("간편식") || name.contains("Take") { return "🥪" }
        return "🍴"
    }
}
