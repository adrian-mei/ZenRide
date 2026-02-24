import SwiftUI
import PhotosUI

// MARK: - Neon Colors

private let neonColors: [(name: String, hex: String)] = [
    ("Cyan",   "00FFFF"),
    ("Green",  "00FF7F"),
    ("Purple", "9B59B6"),
    ("Orange", "FF6B35"),
    ("Pink",   "FF1493"),
    ("Blue",   "007AFF"),
]

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - VehicleGarageView

struct VehicleGarageView: View {
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var driveStore: DriveStore

    @State private var selectedPage: UUID? = nil
    @State private var showAddVehicle = false
    @State private var editingVehicle: Vehicle? = nil

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("MY GARAGE")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .kerning(2)

                    Spacer()

                    Button {
                        showAddVehicle = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                            Text("Add")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.cyan.opacity(0.4), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                if vehicleStore.vehicles.isEmpty {
                    emptyState
                } else {
                    garageContent
                }
            }
        }
        .onAppear {
            if selectedPage == nil {
                selectedPage = vehicleStore.selectedVehicleId ?? vehicleStore.vehicles.first?.id
            }
        }
        .sheet(isPresented: $showAddVehicle) {
            AddVehicleSheet { newVehicle in
                vehicleStore.addVehicle(newVehicle)
                selectedPage = newVehicle.id
            }
        }
        .sheet(item: $editingVehicle) { vehicle in
            EditVehicleSheet(vehicle: vehicle) { updated in
                vehicleStore.updateVehicle(updated)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "car.2.fill")
                .font(.system(size: 64))
                .foregroundColor(.cyan.opacity(0.5))
            Text("Your garage is empty")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Add your first vehicle to get started")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
            Button {
                showAddVehicle = true
            } label: {
                Text("Add Vehicle")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.cyan)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    // MARK: - Garage Content

    private var garageContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Vehicle Carousel
                TabView(selection: $selectedPage) {
                    ForEach(vehicleStore.vehicles) { vehicle in
                        VehicleCard(vehicle: vehicle, isDefault: vehicleStore.selectedVehicleId == vehicle.id)
                            .tag(Optional(vehicle.id))
                            .padding(.horizontal, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 200)

                // Action buttons for selected vehicle
                if let vehicle = currentVehicle {
                    HStack(spacing: 12) {
                        Button {
                            if vehicleStore.selectedVehicleId != vehicle.id {
                                vehicleStore.setDefault(id: vehicle.id)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: vehicleStore.selectedVehicleId == vehicle.id ? "checkmark.circle.fill" : "star.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text(vehicleStore.selectedVehicleId == vehicle.id ? "Active" : "Set Default")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(vehicleStore.selectedVehicleId == vehicle.id ? .green : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                vehicleStore.selectedVehicleId == vehicle.id
                                    ? Color.green.opacity(0.2)
                                    : Color.white.opacity(0.1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        vehicleStore.selectedVehicleId == vehicle.id
                                            ? Color.green.opacity(0.5)
                                            : Color.white.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .disabled(vehicleStore.selectedVehicleId == vehicle.id)

                        Button {
                            editingVehicle = vehicle
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Edit")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    // Stats
                    VehicleStatsSection(vehicle: vehicle, driveStore: driveStore)
                        .padding(.horizontal, 24)

                    // Photo Timeline
                    PhotoTimelineSection(vehicle: vehicle) { updated in
                        vehicleStore.updateVehicle(updated)
                    }
                    .padding(.horizontal, 24)

                    // Maintenance Log
                    MaintenanceLogSection(vehicle: vehicle, currentMileage: vehicle.odometerMiles + driveStore.totalDistanceMiles) { updated in
                        vehicleStore.updateVehicle(updated)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 40)
            }
            .padding(.bottom, 24)
        }
    }

    private var currentVehicle: Vehicle? {
        vehicleStore.vehicles.first(where: { $0.id == selectedPage })
            ?? vehicleStore.vehicles.first
    }
}

// MARK: - Vehicle Card

private struct VehicleCard: View {
    let vehicle: Vehicle
    let isDefault: Bool

    @State private var glowPulse = false

    var accentColor: Color { Color(hex: vehicle.colorHex) }

    var body: some View {
        ZStack {
            // Glow background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.3), Color(red: 0.07, green: 0.07, blue: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [accentColor.opacity(glowPulse ? 0.9 : 0.5), accentColor.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isDefault ? 2 : 1
                )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: vehicle.type.icon)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(accentColor)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if isDefault {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.caption.bold())
                                Text("ACTIVE")
                                    .font(.system(size: 10, weight: .black))
                                    .kerning(1)
                            }
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .clipShape(Capsule())
                        }

                        Text(vehicle.type.displayName.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(accentColor.opacity(0.8))
                            .kerning(1)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.name)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(vehicle.make) \(vehicle.model) \(vehicle.year)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                // Color bar
                Capsule()
                    .fill(accentColor)
                    .frame(height: 3)
                    .shadow(color: accentColor.opacity(0.8), radius: 4, x: 0, y: 0)
            }
            .padding(20)
        }
        .shadow(color: accentColor.opacity(isDefault ? 0.35 : 0.15), radius: 16, x: 0, y: 8)
        .onAppear {
            guard isDefault else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
        .onChange(of: isDefault) { active in
            if active {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            } else {
                glowPulse = false
            }
        }
    }
}

// MARK: - Stats Section

private struct VehicleStatsSection: View {
    let vehicle: Vehicle
    let driveStore: DriveStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("STATS", icon: "chart.bar.fill")

            HStack(spacing: 12) {
                GarageStatBox(title: "Total Miles", value: String(format: "%.0f mi", driveStore.totalDistanceMiles + vehicle.odometerMiles), color: .cyan)
                GarageStatBox(title: "Rides", value: "\(driveStore.totalRideCount)", color: .purple)
                GarageStatBox(title: "Zen Score", value: "\(driveStore.avgZenScore)/100", color: .green)
            }
        }
    }
}

private struct GarageStatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Photo Timeline Section

private struct PhotoTimelineSection: View {
    var vehicle: Vehicle
    let onUpdate: (Vehicle) -> Void

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isLoading = false
    @State private var fullScreenPhoto: VehiclePhoto? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("PHOTO TIMELINE", icon: "camera.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vehicle.photoTimeline) { photo in
                        PhotoThumbnail(photo: photo) {
                            fullScreenPhoto = photo
                        }
                    }

                    // Add photo button
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.cyan)
                            Text("Add")
                                .font(.caption.bold())
                                .foregroundColor(.cyan.opacity(0.8))
                        }
                        .frame(width: 80, height: 80)
                        .background(Color.cyan.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cyan.opacity(0.3), lineWidth: 1, antialiased: true))
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .onChange(of: selectedItem) { item in
            guard let item else { return }
            isLoading = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    var updated = vehicle
                    updated.photoTimeline.append(VehiclePhoto(imageData: data))
                    await MainActor.run {
                        onUpdate(updated)
                        isLoading = false
                        selectedItem = nil
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        selectedItem = nil
                    }
                }
            }
        }
        .sheet(item: $fullScreenPhoto) { photo in
            FullScreenPhotoView(photo: photo)
        }
    }
}

private struct PhotoThumbnail: View {
    let photo: VehiclePhoto
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay(Image(systemName: "photo").foregroundColor(.white.opacity(0.4)))
                }
                Text(shortDate(photo.date))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return fmt.string(from: date)
    }
}

private struct FullScreenPhotoView: View {
    let photo: VehiclePhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                }
                Spacer()

                if let note = photo.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Maintenance Log Section

private struct ServiceReminderBanner: View {
    let vehicle: Vehicle
    let currentMileage: Double

    private var intervalMiles: Double { vehicle.type == .motorcycle ? 3_000 : 5_000 }

    private var lastOilChange: MaintenanceRecord? {
        vehicle.maintenanceLog.first(where: { $0.type == "Oil Change" })
    }

    var body: some View {
        if let last = lastOilChange {
            let remaining = (last.mileageAtService + intervalMiles) - currentMileage
            let isOverdue = remaining <= 0
            let isDueSoon = remaining > 0 && remaining <= 500
            let color: Color = isOverdue ? .red : (isDueSoon ? .orange : .green)
            let icon = isOverdue
                ? "exclamationmark.triangle.fill"
                : (isDueSoon ? "clock.badge.exclamationmark.fill" : "checkmark.shield.fill")
            let label: String = isOverdue
                ? "Oil change overdue by \(Int(abs(remaining))) mi"
                : (isDueSoon
                    ? "Oil change due in \(Int(remaining)) mi"
                    : "Oil change OK · \(Int(remaining)) mi to go")

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.3), lineWidth: 1))
        }
    }
}

private struct MaintenanceLogSection: View {
    var vehicle: Vehicle
    let currentMileage: Double
    let onUpdate: (Vehicle) -> Void

    @State private var showAddRecord = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionHeader("MAINTENANCE LOG", icon: "wrench.and.screwdriver.fill")
                Spacer()
                Button {
                    showAddRecord = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Log Service")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
                }
            }

            ServiceReminderBanner(vehicle: vehicle, currentMileage: currentMileage)

            if vehicle.maintenanceLog.isEmpty {
                Text("No service records yet")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vehicle.maintenanceLog.enumerated()), id: \.element.id) { idx, record in
                        MaintenanceRow(record: record)
                        if idx < vehicle.maintenanceLog.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                                .opacity(0.2)
                        }
                    }
                }
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $showAddRecord) {
            AddMaintenanceSheet(currentMileage: vehicle.odometerMiles) { record in
                var updated = vehicle
                updated.maintenanceLog.insert(record, at: 0)
                onUpdate(updated)
            }
        }
    }
}

private struct MaintenanceRow: View {
    let record: MaintenanceRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: maintenanceIcon(record.type))
                .font(.system(size: 16))
                .foregroundColor(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.type)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                HStack(spacing: 8) {
                    Text(String(format: "%.0f mi", record.mileageAtService))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    if let cost = record.cost {
                        Text("$\(Int(cost))")
                            .font(.caption)
                            .foregroundColor(.green.opacity(0.7))
                    }
                }
            }

            Spacer()

            Text(shortDate(record.date))
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yy"
        return fmt.string(from: date)
    }

    private func maintenanceIcon(_ type: String) -> String {
        switch type {
        case "Oil Change": return "drop.fill"
        case "Tire":       return "circle.circle.fill"
        case "Chain":      return "link"
        case "Service":    return "wrench.fill"
        default:           return "checkmark.seal.fill"
        }
    }
}

// MARK: - Add Maintenance Sheet

struct AddMaintenanceSheet: View {
    let currentMileage: Double
    let onSave: (MaintenanceRecord) -> Void
    @Environment(\.dismiss) private var dismiss

    private let serviceTypes = ["Oil Change", "Tire", "Chain", "Service", "Other"]
    @State private var selectedType = "Oil Change"
    @State private var mileageText = ""
    @State private var noteText = ""
    @State private var costText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Service Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(serviceTypes, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                }

                Section("Mileage at Service") {
                    TextField("e.g. \(Int(currentMileage))", text: $mileageText)
                        .keyboardType(.numberPad)
                }

                Section("Cost (optional)") {
                    TextField("e.g. 45", text: $costText)
                        .keyboardType(.decimalPad)
                }

                Section("Note (optional)") {
                    TextField("Any notes…", text: $noteText)
                }
            }
            .navigationTitle("Log Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let mileage = Double(mileageText) ?? currentMileage
                        let cost = Double(costText)
                        let record = MaintenanceRecord(
                            type: selectedType,
                            mileageAtService: mileage,
                            note: noteText.isEmpty ? nil : noteText,
                            cost: cost
                        )
                        onSave(record)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            mileageText = String(Int(currentMileage))
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Add Vehicle Sheet

struct AddVehicleSheet: View {
    let onSave: (Vehicle) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var make = ""
    @State private var model = ""
    @State private var yearText = ""
    @State private var selectedType: VehicleType = .motorcycle
    @State private var selectedColorHex = "00FFFF"
    @State private var licensePlate = ""
    @State private var odometerText = ""

    var isValid: Bool {
        !name.isEmpty && !make.isEmpty && !model.isEmpty && (Int(yearText) != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle Type") {
                    HStack(spacing: 16) {
                        ForEach(VehicleType.allCases, id: \.self) { type in
                            Button {
                                selectedType = type
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 28))
                                        .foregroundColor(selectedType == type ? .cyan : .white.opacity(0.4))
                                    Text(type.displayName)
                                        .font(.caption.bold())
                                        .foregroundColor(selectedType == type ? .cyan : .white.opacity(0.4))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selectedType == type ? Color.cyan.opacity(0.15) : Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(selectedType == type ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                Section("Identity") {
                    TextField("Nickname (e.g. Black Beast)", text: $name)
                    TextField("Make (e.g. Honda)", text: $make)
                    TextField("Model (e.g. CBR600RR)", text: $model)
                    TextField("Year (e.g. 2021)", text: $yearText)
                        .keyboardType(.numberPad)
                }

                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(neonColors, id: \.hex) { color in
                                Button {
                                    selectedColorHex = color.hex
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: color.hex))
                                            .frame(width: 36, height: 36)
                                            .shadow(color: Color(hex: color.hex).opacity(0.6), radius: 6)
                                        if selectedColorHex == color.hex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .black))
                                                .foregroundColor(.black)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Optional") {
                    TextField("License Plate", text: $licensePlate)
                    TextField("Starting Odometer (miles)", text: $odometerText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let vehicle = Vehicle(
                            name: name,
                            make: make,
                            model: model,
                            year: Int(yearText) ?? Calendar.current.component(.year, from: Date()),
                            type: selectedType,
                            colorHex: selectedColorHex,
                            licensePlate: licensePlate,
                            odometerMiles: Double(odometerText) ?? 0
                        )
                        onSave(vehicle)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Edit Vehicle Sheet

struct EditVehicleSheet: View {
    let vehicle: Vehicle
    let onSave: (Vehicle) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var make: String
    @State private var model: String
    @State private var yearText: String
    @State private var selectedType: VehicleType
    @State private var selectedColorHex: String
    @State private var licensePlate: String
    @State private var odometerText: String

    init(vehicle: Vehicle, onSave: @escaping (Vehicle) -> Void) {
        self.vehicle = vehicle
        self.onSave = onSave
        _name = State(initialValue: vehicle.name)
        _make = State(initialValue: vehicle.make)
        _model = State(initialValue: vehicle.model)
        _yearText = State(initialValue: "\(vehicle.year)")
        _selectedType = State(initialValue: vehicle.type)
        _selectedColorHex = State(initialValue: vehicle.colorHex)
        _licensePlate = State(initialValue: vehicle.licensePlate)
        _odometerText = State(initialValue: "\(Int(vehicle.odometerMiles))")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle Type") {
                    HStack(spacing: 16) {
                        ForEach(VehicleType.allCases, id: \.self) { type in
                            Button {
                                selectedType = type
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 28))
                                        .foregroundColor(selectedType == type ? .cyan : .white.opacity(0.4))
                                    Text(type.displayName)
                                        .font(.caption.bold())
                                        .foregroundColor(selectedType == type ? .cyan : .white.opacity(0.4))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selectedType == type ? Color.cyan.opacity(0.15) : Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(selectedType == type ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                Section("Identity") {
                    TextField("Nickname", text: $name)
                    TextField("Make", text: $make)
                    TextField("Model", text: $model)
                    TextField("Year", text: $yearText).keyboardType(.numberPad)
                }

                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(neonColors, id: \.hex) { color in
                                Button {
                                    selectedColorHex = color.hex
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: color.hex))
                                            .frame(width: 36, height: 36)
                                            .shadow(color: Color(hex: color.hex).opacity(0.6), radius: 6)
                                        if selectedColorHex == color.hex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .black))
                                                .foregroundColor(.black)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Optional") {
                    TextField("License Plate", text: $licensePlate)
                    TextField("Odometer (miles)", text: $odometerText).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = vehicle
                        updated.name = name
                        updated.make = make
                        updated.model = model
                        updated.year = Int(yearText) ?? vehicle.year
                        updated.type = selectedType
                        updated.colorHex = selectedColorHex
                        updated.licensePlate = licensePlate
                        updated.odometerMiles = Double(odometerText) ?? vehicle.odometerMiles
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(name.isEmpty || make.isEmpty || model.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Vehicle Select View (full-screen, used as vehicleSelect AppState)

struct VehicleSelectView: View {
    @EnvironmentObject var vehicleStore: VehicleStore
    let onComplete: () -> Void

    @State private var selectedType: VehicleType = .motorcycle
    @State private var name = ""
    @State private var make = ""
    @State private var model = ""
    @State private var yearText = ""
    @State private var selectedColorHex = "00FFFF"
    @State private var appeared = false

    var isValid: Bool { !name.isEmpty && !make.isEmpty && !model.isEmpty && Int(yearText) != nil }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(white: 0.06)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 48)

                    VStack(spacing: 8) {
                        Text("What do you ride?")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("Add your first vehicle to the garage")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                    }

                    // Type picker
                    HStack(spacing: 16) {
                        ForEach(VehicleType.allCases, id: \.self) { type in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedType = type
                                }
                            } label: {
                                VStack(spacing: 12) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(selectedType == type ? .cyan : .white.opacity(0.3))
                                    Text(type.displayName)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(selectedType == type ? .cyan : .white.opacity(0.3))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .background(
                                    selectedType == type
                                        ? Color.cyan.opacity(0.15)
                                        : Color.white.opacity(0.05)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            selectedType == type ? Color.cyan.opacity(0.6) : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .shadow(color: selectedType == type ? Color.cyan.opacity(0.2) : .clear, radius: 12)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Details form
                    VStack(spacing: 16) {
                        onboardingField("Nickname", placeholder: "e.g. Black Beast", text: $name)
                        onboardingField("Make", placeholder: "e.g. Honda", text: $make)
                        onboardingField("Model", placeholder: "e.g. CBR600RR", text: $model)
                        onboardingField("Year", placeholder: "e.g. 2021", text: $yearText, keyboard: .numberPad)
                    }
                    .padding(.horizontal, 24)

                    // Color picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("COLOR")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .kerning(1.5)
                            .padding(.leading, 4)

                        HStack(spacing: 16) {
                            ForEach(neonColors, id: \.hex) { color in
                                Button {
                                    selectedColorHex = color.hex
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: color.hex))
                                            .frame(width: 44, height: 44)
                                            .shadow(color: Color(hex: color.hex).opacity(0.7), radius: 8)
                                        if selectedColorHex == color.hex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 16, weight: .black))
                                                .foregroundColor(.black)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)

                    // CTA
                    Button {
                        let vehicle = Vehicle(
                            name: name,
                            make: make,
                            model: model,
                            year: Int(yearText) ?? Calendar.current.component(.year, from: Date()),
                            type: selectedType,
                            colorHex: selectedColorHex,
                            licensePlate: "",
                            odometerMiles: 0
                        )
                        vehicleStore.addVehicle(vehicle)
                        onComplete()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedType == .motorcycle ? "motorcycle" : "car.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Let's Roll")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                        .shadow(color: Color.cyan.opacity(0.4), radius: 16, x: 0, y: 8)
                    }
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.5)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
        }
    }

    @ViewBuilder
    private func onboardingField(_ label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .kerning(1.5)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.system(size: 17))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        }
    }
}

// MARK: - Shared Helpers

private func sectionHeader(_ title: String, icon: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: icon)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white.opacity(0.5))
        Text(title)
            .font(.system(size: 11, weight: .black))
            .foregroundColor(.white.opacity(0.5))
            .kerning(1.5)
    }
}
