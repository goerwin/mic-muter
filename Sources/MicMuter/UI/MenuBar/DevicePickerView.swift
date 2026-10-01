import SwiftUI

struct DevicePickerView: View {
    @Bindable var model: MicMuterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Microphone")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Microphone", selection: selection) {
                Text(defaultInputTitle)
                    .tag(nil as String?)

                Divider()

                if model.isSelectedDeviceDisconnected {
                    Text("\(model.selectedInputName) (Unavailable)")
                        .tag(model.selectedDeviceUID)
                        .disabled(true)
                }

                ForEach(model.devices) { device in
                    Text(device.name)
                        .tag(Optional(device.uid))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
            .accessibilityValue(model.selectedInputName)
        }
    }

    private var selection: Binding<String?> {
        Binding(
            get: { model.selectedDeviceUID },
            set: { uid in
                guard let uid else {
                    model.selectDefaultInput()
                    return
                }
                guard let device = model.devices.first(where: { $0.uid == uid }) else { return }
                model.select(device)
            }
        )
    }

    private var defaultInputTitle: String {
        let name = model.currentDefaultDeviceName
        return name == "No input device" ? "System Default" : "System Default (\(name))"
    }
}
