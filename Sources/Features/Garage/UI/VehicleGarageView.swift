import SwiftUI
import PhotosUI

// MARK: - VehicleGarageView

struct VehicleGarageView: View {
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var driveStore: DriveStore

    @State private var selectedPage: UUID? = nil
    @State private var showAddVehicle = false
    @State private var editingVehicle: Vehicle? = nil

    var body: some View {
        ZStack {
            Theme.Colors.acField
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("MY GARAGE")
                        .font(Theme.Typography.title)
                        .foregroundColor(Theme.Colors.acTextDark)

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
                    }
                    .buttonStyle(ACButtonStyle(variant: .secondary))
                    .frame(height: 36) // Override minHeight for a smaller header button
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
            Image(systemName: "tent.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.acLeaf.opacity(0.8))
            Text("Your garage is empty")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.acTextDark)
            Text("Park a vehicle here to start your journey!")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.acTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Add Vehicle") {
                showAddVehicle = true
            }
            .buttonStyle(ACButtonStyle(variant: .primary))
            .padding(.top, 16)
            
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
                            .padding(.vertical, 8)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 240)

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
                                Text(vehicleStore.selectedVehicleId == vehicle.id ? "Active" : "Set Default")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ACButtonStyle(variant: vehicleStore.selectedVehicleId == vehicle.id ? .primary : .secondary))
                        .disabled(vehicleStore.selectedVehicleId == vehicle.id)

                        Button {
                            editingVehicle = vehicle
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                Text("Edit")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ACButtonStyle(variant: .secondary))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Vehicle Icon
                ZStack {
                    Circle()
                        .fill(Theme.Colors.acLeaf.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: vehicle.type.icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.Colors.acLeaf)
                }

                Spacer()

                if isDefault {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 10))
                        Text("ACTIVE")
                            .font(Theme.Typography.button)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(Theme.Colors.acCream)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.acLeaf)
                    .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.name)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .lineLimit(1)

                Text("\(vehicle.make) \(vehicle.model) (\(String(vehicle.year)))")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextMuted)
                    .lineLimit(1)
            }
            
            Divider().background(Theme.Colors.acBorder.opacity(0.3))
            
            // Stats Bars
            VStack(spacing: 8) {
                StatBar(label: "Speed", value: vehicle.speedStat, color: Theme.Colors.acSky)
                StatBar(label: "Handling", value: vehicle.handlingStat, color: Theme.Colors.acGold)
                StatBar(label: "Safety", value: vehicle.safetyStat, color: Theme.Colors.acCoral)
            }
            .padding(.top, 4)
        }
        .acCardStyle(padding: 20, interactive: false)
    }
}

private struct StatBar: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.acTextMuted)
                .frame(width: 60, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.acBorder.opacity(0.3))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, min(geo.size.width * (value / 10.0), geo.size.width)), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Stats Section

private struct VehicleStatsSection: View {
    let vehicle: Vehicle
    let driveStore: DriveStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("CAMPING STATS", icon: "map.fill")

            HStack(spacing: 12) {
                GarageStatBox(title: "Miles Explored", value: String(format: "%.0f mi", driveStore.totalDistanceMiles + vehicle.odometerMiles))
                GarageStatBox(title: "Trips Taken", value: "\(driveStore.totalRideCount)")
            }
        }
    }
}

private struct GarageStatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.acTextDark)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.acTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .acCardStyle(padding: 16)
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
            sectionHeader("SCRAPBOOK", icon: "photo.fill.on.rectangle.fill")

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
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Theme.Colors.acLeaf)
                        }
                        .frame(width: 80, height: 80)
                        .background(Theme.Colors.acCream)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.acBorder, lineWidth: 2))
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 8)
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
            VStack(spacing: 6) {
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.acBorder, lineWidth: 2))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.Colors.acCream)
                        .frame(width: 80, height: 80)
                        .overlay(Image(systemName: "photo").foregroundColor(Theme.Colors.acTextMuted))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.acBorder, lineWidth: 2))
                }
                Text(shortDate(photo.date))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.acTextMuted)
            }
        }
    }

    private func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }
}

private struct FullScreenPhotoView: View {
    let photo: VehiclePhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.Colors.acField.ignoresSafeArea()

            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.Colors.acTextDark)
                    }
                    .padding()
                }
                Spacer()

                if let note = photo.note, !note.isEmpty {
                    Text(note)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextDark)
                        .padding()
                        .background(Theme.Colors.acCream)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.acBorder, lineWidth: 2))
                        .padding(.bottom, 32)
                }
            }
        }
    }
}

// MARK: - Maintenance Log Section

private struct MaintenanceLogSection: View {
    var vehicle: Vehicle
    let currentMileage: Double
    let onUpdate: (Vehicle) -> Void

    @State private var showAddRecord = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionHeader("SERVICE LOG", icon: "wrench.and.screwdriver.fill")
                Spacer()
                Button {
                    showAddRecord = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Log")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .buttonStyle(ACButtonStyle(variant: .secondary))
                .frame(height: 30) // smaller footprint
            }

            if vehicle.maintenanceLog.isEmpty {
                Text("No service records yet")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .acCardStyle(padding: 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vehicle.maintenanceLog.enumerated()), id: \.element.id) { idx, record in
                        MaintenanceRow(record: record)
                        if idx < vehicle.maintenanceLog.count - 1 {
                            Divider().background(Theme.Colors.acBorder.opacity(0.3))
                                .padding(.leading, 16)
                        }
                    }
                }
                .acCardStyle(padding: 0)
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
                .font(.system(size: 18))
                .foregroundColor(Theme.Colors.acWood)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.type)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextDark)
                HStack(spacing: 8) {
                    Text(String(format: "%.0f mi", record.mileageAtService))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
            }

            Spacer()

            Text(shortDate(record.date))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.acTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Service Type")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.acTextDark)
                            
                            Picker("Type", selection: $selectedType) {
                                ForEach(serviceTypes, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.segmented)
                            
                            acTextField(title: "Mileage at Service", placeholder: "e.g. \(Int(currentMileage))", text: $mileageText, keyboard: .numberPad)
                            acTextField(title: "Note (optional)", placeholder: "Any notes…", text: $noteText)
                        }
                        .acCardStyle(padding: 20)
                        
                        Button("Save Record") {
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
                        .buttonStyle(ACButtonStyle(variant: .primary))
                    }
                    .padding()
                }
            }
            .navigationTitle("Log Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.acWood)
                }
            }
        }
        .onAppear {
            mileageText = String(Int(currentMileage))
        }
    }
}

// MARK: - Add/Edit Vehicle Forms & VehicleSelectView

struct AddVehicleSheet: View {
    let onSave: (Vehicle) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var make = ""
    @State private var model = ""
    @State private var yearText = ""
    @State private var selectedType: VehicleType = .car

    var isValid: Bool {
        !name.isEmpty && !make.isEmpty && !model.isEmpty && (Int(yearText) != nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VehicleTypeSelector(selectedType: $selectedType)
                        
                        VStack(spacing: 16) {
                            acTextField(title: "Nickname", placeholder: "e.g. Camp Cruiser", text: $name)
                            acTextField(title: "Make", placeholder: "e.g. Subaru", text: $make)
                            acTextField(title: "Model", placeholder: "e.g. Outback", text: $model)
                            acTextField(title: "Year", placeholder: "e.g. 2024", text: $yearText, keyboard: .numberPad)
                        }
                        .acCardStyle(padding: 20)
                        
                        Button("Add to Garage") {
                            let (spd, hnd, sft) = statsForType(selectedType)
                            let vehicle = Vehicle(
                                name: name,
                                make: make,
                                model: model,
                                year: Int(yearText) ?? Calendar.current.component(.year, from: Date()),
                                type: selectedType,
                                colorHex: "FFFFFF",
                                licensePlate: "",
                                odometerMiles: 0,
                                speedStat: spd,
                                handlingStat: hnd,
                                safetyStat: sft
                            )
                            onSave(vehicle)
                            dismiss()
                        }
                        .buttonStyle(ACButtonStyle(variant: .primary))
                        .disabled(!isValid)
                        .opacity(isValid ? 1 : 0.5)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.acWood)
                }
            }
        }
    }
}

struct EditVehicleSheet: View {
    let vehicle: Vehicle
    let onSave: (Vehicle) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var make: String
    @State private var model: String
    @State private var yearText: String
    @State private var selectedType: VehicleType

    init(vehicle: Vehicle, onSave: @escaping (Vehicle) -> Void) {
        self.vehicle = vehicle
        self.onSave = onSave
        _name = State(initialValue: vehicle.name)
        _make = State(initialValue: vehicle.make)
        _model = State(initialValue: vehicle.model)
        _yearText = State(initialValue: "\(vehicle.year)")
        _selectedType = State(initialValue: vehicle.type)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VehicleTypeSelector(selectedType: $selectedType)
                        
                        VStack(spacing: 16) {
                            acTextField(title: "Nickname", placeholder: "e.g. Camp Cruiser", text: $name)
                            acTextField(title: "Make", placeholder: "e.g. Subaru", text: $make)
                            acTextField(title: "Model", placeholder: "e.g. Outback", text: $model)
                            acTextField(title: "Year", placeholder: "e.g. 2024", text: $yearText, keyboard: .numberPad)
                        }
                        .acCardStyle(padding: 20)
                        
                        Button("Save Changes") {
                            var updated = vehicle
                            updated.name = name
                            updated.make = make
                            updated.model = model
                            updated.year = Int(yearText) ?? vehicle.year
                            updated.type = selectedType
                            // If type changes, maybe we recalculate stats? Or leave them as "customized"
                            // For simplicity we will re-assign defaults for the type.
                            let (spd, hnd, sft) = statsForType(selectedType)
                            updated.speedStat = spd
                            updated.handlingStat = hnd
                            updated.safetyStat = sft
                            
                            onSave(updated)
                            dismiss()
                        }
                        .buttonStyle(ACButtonStyle(variant: .primary))
                        .disabled(name.isEmpty || make.isEmpty || model.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.acWood)
                }
            }
        }
    }
}


// MARK: - Shared Helpers

private func sectionHeader(_ title: String, icon: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(Theme.Colors.acWood)
        Text(title)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(Theme.Colors.acWood)
            .kerning(1.5)
    }
}

private func acTextField(title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(Theme.Typography.body)
            .foregroundColor(Theme.Colors.acTextDark)
        
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .font(Theme.Typography.body)
            .foregroundColor(Theme.Colors.acTextDark)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.Colors.acCream)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.acBorder, lineWidth: 2))
    }
}

private struct VehicleTypeSelector: View {
    @Binding var selectedType: VehicleType
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(VehicleType.allCases, id: \.self) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedType = type
                    }
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: type.icon)
                            .font(.system(size: 32, weight: .bold))
                        Text(type.displayName)
                            .font(Theme.Typography.button)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(selectedType == type ? Theme.Colors.acLeaf.opacity(0.15) : Theme.Colors.acCream)
                    .foregroundColor(selectedType == type ? Theme.Colors.acLeaf : Theme.Colors.acTextMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(selectedType == type ? Theme.Colors.acLeaf : Theme.Colors.acBorder.opacity(0.5), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private func statsForType(_ type: VehicleType) -> (Double, Double, Double) {
    switch type {
    case .motorcycle: return (9.0, 8.0, 2.0)
    case .scooter:    return (4.0, 9.0, 3.0)
    case .bicycle:    return (2.0, 10.0, 1.0)
    case .truck:      return (5.0, 3.0, 10.0)
    case .car:        return (6.0, 5.0, 9.0)
    }
}
