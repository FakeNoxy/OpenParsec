import SwiftUI

struct URLImage<Placeholder: View, RemoteImage: View>: View {
	let url: URL?
	let output: (Image) -> RemoteImage
	let placeholder: () -> Placeholder

	@State private var _remoteData: UIImage?
	@State private var loaded: Bool = false

	var body: some View {
		if let img = _remoteData {
			output(Image(uiImage: img))
		} else {
			placeholder()
				.onAppear {
					guard !loaded, let url = url else { return }
					loaded = true
					Task { @MainActor in
						var request = URLRequest(url: url)
						request.httpMethod = "GET"
						request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
						if let (data, _) = try? await URLSession.shared.data(for: request), let uiImage = UIImage(data: data) {
							_remoteData = uiImage
						}
					}
				}
		}
	}
}
