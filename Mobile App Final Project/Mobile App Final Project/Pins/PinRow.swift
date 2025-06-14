import SwiftUI

struct PinRow: View {
    let pin: Pin
    let isCommon: Bool
    let onSelect: (Pin) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(pin.name)
                    .font(.headline)
                Text(pin.address)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            if isCommon && !(pin.isAdded ?? false) {
                Button(action: {
                    onSelect(pin) // Call when "Add Pin" is pressed
                }) {
                    Text("Add Pin")
                        .foregroundColor(.blue)
                        .padding(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                }
            }
        }
        .contentShape(Rectangle()) // Makes the whole row tappable
        .onTapGesture {
            onSelect(pin)
        }
    }
}

