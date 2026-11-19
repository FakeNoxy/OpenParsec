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
			Color("BackgroundGray")
				.edgesIgnoringSafeArea(.all)

			// Login card
			VStack(spacing: AppSpacing.regular) {
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
				.padding(.top, AppSpacing.wide)

				TextField("Email", text: $inputEmail)
					.padding(AppSpacing.regular)
					.background(
						RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
							.fill(Color("BackgroundField"))
					)
					.disableAutocorrection(true)
					.autocapitalization(.none)
					.keyboardType(.emailAddress)
					.textContentType(.emailAddress)

				SecureField("Password", text: $inputPassword, onCommit: { authenticate() })
					.padding(AppSpacing.regular)
					.background(
						RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
							.fill(Color("BackgroundField"))
					)
					.disableAutocorrection(true)
					.autocapitalization(.none)
					.textContentType(.password)

				Button(action: { authenticate() }) {
					Text("Login")
						.font(.body.weight(.semibold))
				}
				.buttonStyle(PrimaryButtonStyle(fullWidth: true))
				.padding(.top, AppSpacing.tight)
			}
			.padding(AppSpacing.wide)
			.glassCard(cornerRadius: 20, fallbackFill: Color("BackgroundCard"))
			.frame(maxWidth: 420)
			.padding()
			.disabled(viewModel.isLoading) // Disable when loading

			// Loading / 2FA overlay
			if viewModel.isLoading || viewModel.presentTFAAlert {
				ZStack {
					Color.black.opacity(0.5)
						.edgesIgnoringSafeArea(.all)
					VStack(spacing: AppSpacing.regular) {
						if viewModel.isLoading {
							ActivityIndicator(isAnimating: $viewModel.isLoading, style: .large, tint: .white)
								.padding()
							Text("Loading...")
								.font(.body)
								.multilineTextAlignment(.center)
						} else if viewModel.presentTFAAlert {
							Text("Please enter your 2FA code from your authenticator app")
								.font(.subheadline)
								.multilineTextAlignment(.center)
							SecureField("2FA Code", text: $inputTFA)
								.padding(AppSpacing.regular)
								.background(
									RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
										.fill(Color("BackgroundField"))
								)
								.foregroundColor(Color("Foreground"))
								.disableAutocorrection(true)
								.autocapitalization(.none)
								.textContentType(.oneTimeCode)
							HStack(spacing: AppSpacing.tight) {
								Button(action: { viewModel.presentTFAAlert = false }) {
									Text("Cancel")
										.font(.body.weight(.medium))
								}
								.buttonStyle(SubtleButtonStyle())
								Button(action: { authenticate(inputTFA) }) {
									Text("Enter")
										.font(.body.weight(.semibold))
								}
								.buttonStyle(PrimaryButtonStyle(fullWidth: true))
							}
						}
					}
					.padding(AppSpacing.wide)
					.glassCard(cornerRadius: 20, fallbackFill: Color("BackgroundPrompt"))
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
