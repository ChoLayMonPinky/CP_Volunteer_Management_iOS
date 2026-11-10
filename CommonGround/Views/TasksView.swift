import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.duoMode) private var duoMode
    var embedsNavigation: Bool = true
    @State private var tasks: [ApiTask] = []
    @State private var error: String?
    @State private var loading = false
    @State private var busyId: String?

    var body: some View {
        Group {
            if embedsNavigation {
                NavigationStack { tasksContent }
            } else {
                tasksContent
            }
        }
    }

    private var tasksContent: some View {
        Group {
            if loading && tasks.isEmpty {
                ProgressView("Loading tasks…")
                    .tint(AppColors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, tasks.isEmpty {
                CGEmptyState(title: "Couldn’t load tasks", systemImage: "exclamationmark.triangle.fill", message: error)
            } else if tasks.isEmpty {
                CGEmptyState(
                    title: "No tasks assigned",
                    systemImage: "checklist",
                    message: "Tasks from your organizers will show up here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(tasks) { task in
                            TaskRow(task: task, busy: busyId == task.id) { status in
                                await setStatus(task, status)
                            }
                        }
                    }
                    .padding(.horizontal, duoMode.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, duoMode.chatClearance)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(CGScreenBackground())
        .navigationTitle("Tasks")
        .commonGroundToolbar()
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let token = authStore.session?.accessToken else { return }
        loading = tasks.isEmpty
        error = nil
        do {
            tasks = try await APIClient.shared.myTasks(token: token)
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
        loading = false
    }

    private func setStatus(_ task: ApiTask, _ status: String) async {
        guard let token = authStore.session?.accessToken else { return }
        busyId = task.id
        do {
            let updated = try await APIClient.shared.setTaskStatus(id: task.id, status: status, token: token)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx] = updated
            }
        } catch {
            self.error = authStore.friendlyMessage(for: error)
        }
        busyId = nil
    }
}

private struct TaskRow: View {
    let task: ApiTask
    let busy: Bool
    let onStatus: (String) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(task.title ?? "Untitled task")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text((task.priority ?? "MEDIUM").capitalized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.onPrimaryContainer)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.primaryContainer, in: Capsule())
            }

            if let description = task.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(3)
            }

            HStack {
                if let due = task.dueDate {
                    Label(due, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(AppColors.textMuted)
                }
                Spacer()
                if busy {
                    ProgressView().controlSize(.small)
                } else {
                    Menu {
                        Button("To do") { Task { await onStatus("TODO") } }
                        Button("In progress") { Task { await onStatus("IN_PROGRESS") } }
                        Button("Done") { Task { await onStatus("DONE") } }
                    } label: {
                        Text((task.status ?? "TODO").replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.accentText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.primaryContainer, in: Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppColors.hairline, lineWidth: 1)
        )
    }
}
