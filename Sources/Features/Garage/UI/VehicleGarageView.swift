import SwiftUI
import PhotosUI

// MARK: - VehicleGarageView

struct VehicleGarageView: View {
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var driveStore: DriveStore
    @EnvironmentObject var playerStore: PlayerStore

    @State private var selectedPage: UUID? = nil
    @State private var showAddVehicle = false
    @State private var editingVehicle: Vehicle? = nil
    @State private var selectedTab: Int = 0 // 0 = Garage, 1 = Campers

    var body: some View {
        ZStack {
            Theme.Colors.acField
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(selectedTab == 0 ? "MY GARAGE" : "MY CAMPERS")
                        .font(Theme.Typography.title)
                        .foregroundColor(Theme.Colors.acTextDark)

                    Spacer()

                    if selectedTab == 0 {
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
                        .frame(height: 36)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 8)
                
                Picker("", selection: $selectedTab) {
                    Text("Vehicles").tag(0)
                    Text("Characters").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                if selectedTab == 0 {
                    if vehicleStore.vehicles.isEmpty {
                        emptyState
                    } else {
                        garageContent
                    }
                } else {
                    CharacterSelectionView()
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

// MARK: - Character Selection View

struct CharacterSelectionView: View {
    @EnvironmentObject var playerStore: PlayerStore
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Character.all) { character in
                    let isUnlocked = character.unlockLevel <= playerStore.currentLevel
                    let isSelected = playerStore.selectedCharacterId == character.id
                    
                    Button {
                        if isUnlocked {
                            playerStore.selectCharacter(character)
                        }
                    } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isUnlocked ? Color(hex: character.colorHex) : Theme.Colors.acBorder.opacity(0.3))
                                    .frame(width: 80, height: 80)
                                    .overlay(Circle().stroke(isSelected ? Theme.Colors.acLeaf : Theme.Colors.acBorder.opacity(0.2), lineWidth: isSelected ? 4 : 2))

                                if isUnlocked {
                                    Image(systemName: character.icon)
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(Theme.Colors.acTextMuted)
                                }
                            }

                            VStack(spacing: 4) {
                                Text(isUnlocked ? character.name : "Locked")
                                    .font(Theme.Typography.headline)
                                    .foregroundColor(isUnlocked ? Theme.Colors.acTextDark : Theme.Colors.acTextMuted)

                                if isSelected {
                                    ACBadge(text: "ACTIVE")
                                } else if !isUnlocked {
                                    Text("Level \(character.unlockLevel)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Theme.Colors.acWood)
                                } else {
                                    Text("Tap to Select")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.Colors.acTextMuted)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Theme.Colors.acCream)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .contentShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? Theme.Colors.acLeaf : Theme.Colors.acBorder.opacity(0.4), lineWidth: 2))
                        .opacity(isUnlocked ? 1.0 : 0.6)
                        .shadow(color: isSelected ? Theme.Colors.acLeaf.opacity(0.2) : .clear, radius: 8, y: 4)
                        .bunnyPaw()
                    }
                    .buttonStyle(.plain)
                    .disabled(!isUnlocked)
                    .accessibilityLabel(isUnlocked ? character.name : "\(character.name), locked")
                    .accessibilityHint(
                        isSelected ? "Currently active" :
                        isUnlocked ? "Double tap to select" :
                        "Unlocks at level \(character.unlockLevel)"
                    )
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
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
                    ACBadge(text: "ACTIVE", icon: "leaf.fill")
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
                ACStatBar(label: "Speed", value: vehicle.speedStat, color: Theme.Colors.acSky)
                ACStatBar(label: "Handling", value: vehicle.handlingStat, color: Theme.Colors.acGold)
                ACStatBar(label: "Safety", value: vehicle.safetyStat, color: Theme.Colors.acCoral)
            }
            .padding(.top, 4)
        }
        .acCardStyle(padding: 20, interactive: false)
    }
}


// MARK: - Stats Section

private struct VehicleStatsSection: View {
    let vehicle: Vehicle
    let driveStore: DriveStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ACSectionHeader(title: "CAMPING STATS", icon: "map.fill")

            HStack(spacing: 12) {
                ACStatBox(title: "Miles Explored", value: String(format: "%.0f mi", driveStore.totalDistanceMiles + vehicle.odometerMiles))
                ACStatBox(title: "Trips Taken", value: "\(driveStore.totalRideCount)")
            }
        }
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
            ACSectionHeader(title: "SCRAPBOOK", icon: "photo.fill.on.rectangle.fill")

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
        .onChange(of: selectedItem) { _, item in
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
                ACSectionHeader(title: "SERVICE LOG", icon: "wrench.and.screwdriver.fill")
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
                            
                            ACTextField(title: "Mileage at Service", placeholder: "e.g. \(Int(currentMileage))", text: $mileageText, keyboard: .numberPad)
                            ACTextField(title: "Note (optional)", placeholder: "Any notes…", text: $noteText)
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
                            ACTextField(title: "Nickname", placeholder: "e.g. Camp Cruiser", text: $name)
                            ACTextField(title: "Make", placeholder: "e.g. Subaru", text: $make)
                            ACTextField(title: "Model", placeholder: "e.g. Outback", text: $model)
                            ACTextField(title: "Year", placeholder: "e.g. 2024", text: $yearText, keyboard: .numberPad)
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
                            ACTextField(title: "Nickname", placeholder: "e.g. Camp Cruiser", text: $name)
                            ACTextField(title: "Make", placeholder: "e.g. Subaru", text: $make)
                            ACTextField(title: "Model", placeholder: "e.g. Outback", text: $model)
                            ACTextField(title: "Year", placeholder: "e.g. 2024", text: $yearText, keyboard: .numberPad)
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



private struct VehicleTypeSelector: View {
    @Binding var selectedType: VehicleType

    // Group types into labelled sections for clarity
    private let groups: [(label: String, types: [VehicleType])] = [
        ("Cars",       [.car, .sportsCar, .electricCar, .suv, .truck]),
        ("Two-wheels", [.motorcycle, .scooter, .bicycle, .mountainBike]),
        ("On Foot",    [.walking, .running, .skateboard])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups, id: \.label) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.label.uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(Theme.Colors.acTextMuted)
                        .kerning(1.2)

                    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(group.types, id: \.self) { type in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedType = type
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 22, weight: .bold))
                                    Text(type.displayName)
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedType == type ? Theme.Colors.acLeaf.opacity(0.15) : Theme.Colors.acCream)
                                .foregroundColor(selectedType == type ? Theme.Colors.acLeaf : Theme.Colors.acTextMuted)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            selectedType == type ? Theme.Colors.acLeaf : Theme.Colors.acBorder.opacity(0.4),
                                            lineWidth: selectedType == type ? 2 : 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// Speed, Handling, Safety
private func statsForType(_ type: VehicleType) -> (Double, Double, Double) {
    switch type {
    case .car:          return (6.0, 5.0, 9.0)
    case .sportsCar:    return (10.0, 9.0, 3.0)
    case .electricCar:  return (7.0, 8.0, 8.0)
    case .suv:          return (5.0, 4.0, 9.5)
    case .truck:        return (5.0, 3.0, 10.0)
    case .motorcycle:   return (9.0, 8.0, 2.0)
    case .scooter:      return (4.0, 9.0, 3.0)
    case .bicycle:      return (2.0, 10.0, 1.0)
    case .mountainBike: return (3.0, 9.0, 4.0)
    case .walking:      return (1.0, 10.0, 10.0)
    case .running:      return (3.0, 10.0, 8.0)
    case .skateboard:   return (4.0, 9.0, 2.0)
    }
}
