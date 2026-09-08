import SwiftUI
import AppKit

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

            // Meal Type Tabs (조식, 중식, 석식)
            HStack(spacing: 6) {
                ForEach(MealType.allCases) { type in
                    let isSelected = viewModel.selectedMealType == type
                    Button {
                        viewModel.selectedMealType = type
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.system(size: 10))
                            Text(type.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(isSelected ? Color.secondary.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(6)

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

            // Menu Content List
            ScrollView {
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
                        } else {
                            ForEach(categories) { category in
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
            }
            .frame(maxHeight: 250)

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
