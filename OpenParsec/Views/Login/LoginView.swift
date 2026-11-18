import SwiftUI

struct LoginView: View {
	var controller: ContentView?
	@ObservedObject var viewModel: LoginViewModel

	@State var inputEmail: String = ""
	@State var inputPassword: String = ""
	@State var inputTFA: String = ""

	init(_ controller: ContentView?, viewModel: LoginViewModel) {
		self.controller = controller
		self.viewModel = viewModel
	}

	var body: some View {
		ZStack {
			// Background
			Rectangle()
				.fill(Color("BackgroundGray"))
				.edgesIgnoringSafeArea(.all)

			// Login controls
			VStack(spacing: 8) {
				HStack(spacing: 2) {
					Image("IconTransparent")
						.resizable()
						.aspectRatio(contentMode: .fit)
					Image("LogoShadow")
						.resizable()
						.aspectRatio(contentMode: .fit)
						.padding([.top, .bottom, .trailing])
				}
				.frame(height: 80)
				TextField("Email", text: $inputEmail)
					.padding()
					.background(Rectangle().fill(Color("BackgroundField")))
					.cornerRadius(8)
					.disableAutocorrection(true)
					.autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
					.keyboardType(.emailAddress)
					.textContentType(.emailAddress)
				SecureField("Password", text: $inputPassword, onCommit: { authenticate() })
					.padding()
					.background(Rectangle().fill(Color("BackgroundField")))
					.cornerRadius(8)
					.disableAutocorrection(true)
					.autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
					.textContentType(.password)
				Button(action: {authenticate()}) {
					ZStack {
						Rectangle()
							.fill(Color("AccentColor"))
							.cornerRadius(8)
						Text("Login")
							.foregroundColor(.white)
					}
					.frame(height: 54)
				}
			}

			.padding()
			.frame(maxWidth: 400)
			.disabled(viewModel.isLoading) // Disable when loading

			// Loading elements
			if viewModel.isLoading || viewModel.presentTFAAlert {
				ZStack {
					Rectangle() // Darken background
						.fill(Color.black)
						.opacity(0.5)
						.edgesIgnoringSafeArea(.all)
					VStack {
						if viewModel.isLoading {
							ActivityIndicator(isAnimating: $viewModel.isLoading, style: .large, tint: .white)
							 .padding()
						 Text("Loading...")
							 .multilineTextAlignment(.center)
						} else if viewModel.presentTFAAlert {
							Text("Please enter your 2FA code from your authenticator app")
								.multilineTextAlignment(.center)
							SecureField("2FA Code", text: $inputTFA)
								.padding()
								.background(Rectangle().fill(Color("BackgroundField")))
								.foregroundColor(Color("Foreground"))
								.cornerRadius(8)
								.disableAutocorrection(true)
								.autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
								.textContentType(.oneTimeCode)
							HStack {
								Button(action: {viewModel.presentTFAAlert = false}) {
									ZStack {
										Rectangle()
											.fill(Color("BackgroundButton"))
											.cornerRadius(8)
										Text("Cancel")
											.foregroundColor(Color("Foreground"))
									}
									.frame(height: 54)
								}
								Button(action: {authenticate(inputTFA)}) {
									ZStack {
										Rectangle()
											.fill(Color("AccentColor"))
											.cornerRadius(8)
										Text("Enter")
											.foregroundColor(.white)
									}
									.frame(height: 54)
								}
							}
						}
					}
					.padding()
					.background(Rectangle().fill(Color("BackgroundPrompt")))
					.cornerRadius(8)
					.padding()
				}
			}
		}
		.foregroundColor(Color("Foreground"))
		.alert(isPresented: $viewModel.showAlert) {
			Alert(title: Text("Login Failed"), message: Text(viewModel.alertText))
		}
		.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in retryRestore() }
		.onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in retryRestore() }
	}

	func retryRestore() {
		if !viewModel.isLoading && !viewModel.presentTFAAlert, let c = controller {
			c.retryRestore()
		}
	}

	func authenticate(_ tfa: String? = "") {
		#if DEBUG
		if inputEmail == "test@example.com" { // skip authentication (DEBUG ONLY)
			if let c = controller {
				c.setView(.main)
			}
			return
		}
		#endif

		viewModel.authenticate(email: inputEmail, password: inputPassword, tfa: tfa)
	}
}

struct LoginView_Previews: PreviewProvider {
	static var previews: some View {
		LoginView(nil, viewModel: LoginViewModel())
	}
}
