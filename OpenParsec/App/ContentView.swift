import SwiftUI

enum ViewType {
	case login
	case main
	case parsec
}

struct ContentView: View {
	@State var curView: ViewType = .login

	// Shared view models (owned here so both the view and child views use the same instance)
	@StateObject private var loginVM = LoginViewModel()
	@StateObject private var mainVM = MainViewModel()

	let defaultTransition = AnyTransition.move(edge: .trailing)

	var body: some View {
		ZStack {
			switch curView {
				case .login:
					LoginView(self, viewModel: loginVM)
				case .main:
					MainView(self, viewModel: mainVM)
						.transition(defaultTransition)
				case .parsec:
					ParsecView(self)
				}
		}
		.onAppear {
			loginVM.onAuthenticated = { self.setView(.main) }
			mainVM.onConnected = { self.setView(.parsec) }
			mainVM.onLogout = { self.setView(.login) }
			initApp()
		}
		.background(Rectangle().fill(Color.black).edgesIgnoringSafeArea(.all))
	}

	func retryRestore() {
		if curView == .login && SessionStore.clinfo == nil {
			initApp()
		}
	}

	func initApp() {
		if loginVM.restore() {
			curView = .main
		}
	}

	public func setView(_ t: ViewType) {
		withAnimation(.easeInOut) { curView = t }
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
