import SwiftUI
import SwiftData
import PhotosUI

/// Run the checklist for one asset. Everything starts as OK; untick what is wrong. Saving is the success moment.
struct InspectionSheet: View {
    let asset: Asset
    var existing: Inspection? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @AppStorage("inspector.name") private var defaultInspector = ""

    @State private var date: Date = .now
    @State private var inspector = ""
    @State private var okItems: Set<String> = []
    @State private var notes = ""
    @State private var photo: Data?
    @State private var pickerItem: PhotosPickerItem?

    private var failedItems: [String] { asset.type.checklist.filter { !okItems.contains($0) } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: asset.type.symbol).font(.title2).foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(asset.title).font(.headline)
                            Text([asset.type.name, asset.location].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    DatePicker("Inspected", selection: $date)
                    TextField("Inspector", text: $inspector)
                }

                Section {
                    ForEach(asset.type.checklist, id: \.self) { item in
                        Toggle(isOn: Binding(get: { okItems.contains(item) }, set: { on in if on { okItems.insert(item) } else { okItems.remove(item) } })) {
                            Text(item).font(.subheadline)
                        }
                        .tint(.green)
                    }
                } header: {
                    HStack {
                        Text("Checklist")
                        Spacer()
                        Button("All OK") { okItems = Set(asset.type.checklist) }.font(.caption)
                    }
                } footer: {
                    Text(failedItems.isEmpty ? "Result: Pass" : "Result: Needs attention (\(failedItems.count) item\(failedItems.count == 1 ? "" : "s"))")
                        .foregroundStyle(failedItems.isEmpty ? Color.green : Color.orange)
                        .font(.footnote.weight(.semibold))
                }

                if !DueCalculator.expiringItems(for: asset).isEmpty {
                    Section("Service dates coming up") {
                        ForEach(DueCalculator.expiringItems(for: asset), id: \.label) { item in
                            LabeledContent(item.label, value: item.days < 0 ? "\(Formatters.days(-item.days)) ago" : Formatters.date.string(from: item.date))
                                .foregroundStyle(item.days < 0 ? .red : .primary)
                        }
                    }
                }

                Section("Notes and photo") {
                    TextEditor(text: $notes).frame(minHeight: 70)
                    if let photo, let image = UIImage(data: photo) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200).clipShape(RoundedRectangle(cornerRadius: 8))
                        Button("Remove photo", role: .destructive) { self.photo = nil }
                    }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(photo == nil ? "Add photo" : "Replace photo", systemImage: "photo")
                    }
                }
            }
            .navigationTitle(existing == nil ? "Inspect" : "Edit Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.bold() }
            }
            .onAppear(perform: load)
            .onChange(of: pickerItem) {
                guard let pickerItem else { return }
                Task { if let data = try? await pickerItem.loadTransferable(type: Data.self) { photo = ImageCompressor.compress(data) } }
            }
        }
    }

    private func load() {
        if let existing {
            date = existing.date
            inspector = existing.inspector
            okItems = Set(asset.type.checklist).subtracting(existing.failedItems)
            notes = existing.notes
            photo = existing.photo
        } else {
            inspector = defaultInspector
            okItems = Set(asset.type.checklist)
        }
    }

    private func save() {
        let target = existing ?? Inspection(asset: asset, date: date, inspector: inspector)
        target.date = date
        target.inspector = inspector
        target.failedItems = failedItems
        target.notes = notes
        target.photo = photo
        if existing == nil { context.insert(target) }
        if !inspector.isEmpty { defaultInspector = inspector }
        ReviewPrompter.recordSuccess(request: requestReview)
        dismiss()
    }
}

enum ImageCompressor {
    static func compress(_ data: Data, maxDimension: CGFloat = 1200) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
