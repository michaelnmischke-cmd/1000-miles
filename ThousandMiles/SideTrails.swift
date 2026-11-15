import SwiftUI

/// Lets `.sheet(item:)` open a goal by its id.
private struct GoalRef: Identifiable {
    let id: CustomGoal.ID
}

// MARK: - Section on the progress screen

/// "Side trails": hand-logged yearly goals like 500 pull-ups, shown as small rings.
struct SideTrailsSection: View {
    @Environment(GoalsStore.self) private var store
    @State private var isAdding = false
    @State private var openGoal: GoalRef?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow("Side trails")
                Spacer()
                if !store.goals.isEmpty {
                    Button {
                        isAdding = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .textCase(.uppercase)
                    }
                    .tint(Theme.trail)
                }
            }

            if store.goals.isEmpty {
                Button {
                    isAdding = true
                } label: {
                    Label("Add a side trail, like 500 pull-ups", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Theme.inkMuted)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Theme.path, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        )
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(Array(store.goals.enumerated()), id: \.element.id) { index, goal in
                            Button {
                                openGoal = GoalRef(id: goal.id)
                            } label: {
                                GoalTile(goal: goal, color: Theme.goalColor(index), year: store.currentYear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .card()
        .sheet(isPresented: $isAdding) {
            GoalEditor(existing: nil)
                .environment(store)
        }
        .sheet(item: $openGoal) { ref in
            GoalDetailScreen(goalID: ref.id)
                .environment(store)
        }
    }
}

/// One small ring with the goal's name and count underneath.
struct GoalTile: View {
    let goal: CustomGoal
    let color: Color
    let year: Int

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                ProgressRing(fraction: goal.fraction(in: year), lineWidth: 5, color: color)
                Text("\(goal.percent(in: year))")
                    .font(Theme.display(15, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 48, height: 48)

            Text(goal.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text("\(goal.total(in: year).formatted())/\(goal.target.formatted())")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(Theme.inkMuted)
        }
        .frame(width: 84)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the goal to log progress")
    }
}

// MARK: - Goal detail: log progress

struct GoalDetailScreen: View {
    let goalID: CustomGoal.ID

    @Environment(GoalsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var customAmount: Int?
    @FocusState private var amountFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let goal = store.goal(id: goalID) {
                    content(goal)
                } else {
                    // The goal was deleted.
                    Color.clear.onAppear { dismiss() }
                }
            }
            .background {
                ZStack {
                    Theme.paper
                    TopoBackground()
                }
                .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Edit") { isEditing = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isEditing) {
                if let goal = store.goal(id: goalID) {
                    GoalEditor(existing: goal)
                        .environment(store)
                }
            }
        }
        .tint(Theme.trail)
    }

    private func content(_ goal: CustomGoal) -> some View {
        let year = store.currentYear
        let total = goal.total(in: year)
        let index = store.goals.firstIndex(where: { $0.id == goal.id }) ?? 0
        let entries = goal.entries(in: year)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow("Side trail · \(String(year))")
                    Text(goal.name.uppercased())
                        .font(Theme.display(40))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                HStack(spacing: 20) {
                    ZStack {
                        ProgressRing(fraction: goal.fraction(in: year), lineWidth: 12, color: Theme.goalColor(index))
                        Text("\(goal.percent(in: year))%")
                            .font(Theme.display(28, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                    }
                    .frame(width: 130, height: 130)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(total.formatted())
                            .font(Theme.display(48))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        Text("of \(goal.target.formatted()) \(goal.unit)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.inkMuted)
                        Text(paceText(goal: goal, total: total))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.forest)
                    }
                }
                .sensoryFeedback(.increase, trigger: total)

                // Quick add
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Log \(goal.unit)")
                    HStack(spacing: 8) {
                        ForEach([1, 5, 10], id: \.self) { amount in
                            Button {
                                withAnimation { store.log(amount, to: goal.id) }
                            } label: {
                                Text("+\(amount)")
                                    .font(Theme.display(26, weight: .heavy))
                                    .frame(maxWidth: .infinity)
                                    .signPlate()
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add \(amount) \(goal.unit)")
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Other amount", value: $customAmount, format: .number)
                            .keyboardType(.numberPad)
                            .focused($amountFocused)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Theme.track.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Button("Add") {
                            if let amount = customAmount, amount > 0 {
                                withAnimation { store.log(amount, to: goal.id) }
                            }
                            customAmount = nil
                            amountFocused = false
                        }
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .foregroundStyle(.white)
                        .background(Theme.trail, in: Capsule())
                        .disabled((customAmount ?? 0) <= 0)
                    }

                    if !entries.isEmpty {
                        Button {
                            withAnimation { store.undoLast(on: goal.id) }
                        } label: {
                            Label("Undo last (+\(entries.first?.amount ?? 0))", systemImage: "arrow.uturn.backward")
                                .font(.footnote.weight(.semibold))
                        }
                        .tint(Theme.trail)
                    }
                }
                .card()

                // Log
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow("Trail log")
                        .padding(.bottom, 8)
                    if entries.isEmpty {
                        Text("Nothing logged yet this year.")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkMuted)
                    } else {
                        ForEach(entries.prefix(50)) { entry in
                            HStack {
                                Text(entry.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(.footnote)
                                    .foregroundStyle(Theme.inkMuted)
                                Spacer()
                                Text("+\(entry.amount.formatted())")
                                    .font(Theme.display(20, weight: .heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.ink)
                                Button {
                                    withAnimation { store.removeEntry(entry.id, from: goal.id) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.footnote)
                                        .foregroundStyle(Theme.inkMuted)
                                        .padding(.leading, 12)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete this entry")
                            }
                            .padding(.vertical, 8)
                            .overlay(alignment: .bottom) { DashedRule() }
                        }
                    }
                }
                .card()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func paceText(goal: CustomGoal, total: Int) -> String {
        let left = goal.target - total
        guard left > 0 else { return "Goal reached!" }
        let calendar = Calendar.current
        let now = Date()
        let endOfYear = calendar.dateInterval(of: .year, for: now)?.end ?? now
        let daysLeft = max(calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: endOfYear).day ?? 1, 1)
        let perDay = Double(left) / Double(daysLeft)
        let perDayText = perDay.formatted(.number.precision(.fractionLength(perDay < 10 ? 1 : 0)))
        return "\(left.formatted()) to go · \(perDayText) a day"
    }
}

// MARK: - Add or edit a goal

struct GoalEditor: View {
    let existing: CustomGoal?

    @Environment(GoalsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var unit = ""
    @State private var target: Int? = nil
    @State private var confirmDelete = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (target ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                if existing == nil {
                    Section("Quick pick") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(GoalPreset.all) { preset in
                                    Button {
                                        name = preset.name
                                        unit = preset.unit
                                        target = preset.target
                                    } label: {
                                        Text(preset.name)
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .foregroundStyle(name == preset.name ? Theme.paper : Theme.ink)
                                            .background(name == preset.name ? Theme.ink : Color.clear, in: Capsule())
                                            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section {
                    TextField("Name, like Pull-ups", text: $name)
                    TextField("What you count, like pull-ups", text: $unit)
                        .textInputAutocapitalization(.never)
                    HStack {
                        Text("Yearly goal")
                        Spacer()
                        TextField("500", value: $target, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                } footer: {
                    Text("Runs January 1 to December 31. Log progress with the +1, +5 and +10 buttons.")
                }

                if existing != nil {
                    Section {
                        Button("Delete this goal", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle(existing == nil ? "New side trail" : "Edit side trail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .confirmationDialog("Delete \(name)? Everything you've logged for it will be removed.",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let existing { store.delete(id: existing.id) }
                    dismiss()
                }
            }
            .onAppear {
                if let existing {
                    name = existing.name
                    unit = existing.unit
                    target = existing.target
                }
            }
        }
        .tint(Theme.trail)
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        let cleanUnit = unit.trimmingCharacters(in: .whitespaces)
        let finalUnit = cleanUnit.isEmpty ? cleanName.lowercased() : cleanUnit
        let finalTarget = max(target ?? 1, 1)
        if var goal = existing {
            goal.name = cleanName
            goal.unit = finalUnit
            goal.target = finalTarget
            store.update(goal)
        } else {
            store.add(name: cleanName, unit: finalUnit, target: finalTarget)
        }
        dismiss()
    }
}
