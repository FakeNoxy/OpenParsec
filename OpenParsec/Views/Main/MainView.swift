import SwiftUI
import ParsecSDK

struct MainView: View {
	var controller: ContentView?
	@ObservedObject var viewModel: MainViewModel

	@State private var page: Page = .hosts
	@State var inSettings: Bool = false
	@State private var showLogoutAlert = false

	var busy: Bool {
		viewModel.isConnecting || inSettings
	}

	init(_ controller: ContentView?, viewModel: MainViewModel) {
		self.controller = controller
		self.viewModel = viewModel
	}

	var body: some View {
		ZStack {
			// Background
			Color("BackgroundTab")
				.edgesIgnoringSafeArea(.all)

			// Main content: system TabView so iPhone Duo places controls on
			// the vertical axis automatically (outer display / landscape inner).
			TabView(selection: $page) {
				NavigationStack {
					HostsPage(viewModel: viewModel)
						.navigationTitle(viewModel.hostCountStr)
						.navigationBarTitleDisplayMode(.inline)
						.toolbar {
							ToolbarItem(placement: .topBarLeading) {
								Button(action: { showLogoutAlert = true }, label: {
									Image("SymbolExit").scaleEffect(x: -1)
								})
								.foregroundColor(Color("AccentColor"))
							}
							ToolbarItem(placement: .topBarTrailing) {
								Button(action: viewModel.refreshHosts, label: {
									if viewModel.isRefreshing {
										ProgressView()
									} else {
										Image(systemName: "arrow.clockwise")
									}
								})
								.foregroundColor(Color("AccentColor"))
								.disabled(viewModel.isRefreshing)
							}
							ToolbarItem(placement: .topBarTrailing) {
								Button(action: { withAnimation(.easeInOut(duration: 0.24)) { inSettings = true } }, label: {
									Image(systemName: "gear")
								})
								.foregroundColor(Color("AccentColor"))
							}
						}
				}
				.tag(Page.hosts)
				.tabItem {
					Label("Hosts", systemImage: "desktopcomputer")
				}

				NavigationStack {
					FriendsPage(viewModel: viewModel)
						.navigationTitle(viewModel.friendCountStr)
						.navigationBarTitleDisplayMode(.inline)
						.toolbar {
							ToolbarItem(placement: .topBarLeading) {
								Button(action: { showLogoutAlert = true }, label: {
									Image("SymbolExit").scaleEffect(x: -1)
								})
								.foregroundColor(Color("AccentColor"))
							}
							ToolbarItem(placement: .topBarTrailing) {
								Button(action: { withAnimation(.easeInOut(duration: 0.24)) { inSettings = true } }, label: {
									Image(systemName: "gear")
								})
								.foregroundColor(Color("AccentColor"))
							}
						}
				}
				.tag(Page.friends)
				.tabItem {
					Label("Friends", systemImage: "person.2.fill")
				}
			}
			.alert(isPresented: $showLogoutAlert) {
				Alert(title: Text("Are you sure you want to logout?"), primaryButton: .destructive(Text("Logout"), action: viewModel.logout), secondaryButton: .cancel(Text("Cancel")))
			}
			.alert(isPresented: $viewModel.showBaseAlert) {
				Alert(title: Text(viewModel.baseAlertText))
			}
			.onAppear(perform: viewModel.initView)
			.onDisappear { ParsecBackgroundManager.shared.canShortcutReconnect = false }
			.disabled(busy) // disable view if busy

			// Settings screen
			SettingsView(visible: $inSettings)

			// Connecting overlay
			if viewModel.isConnecting {
				ZStack {
					Color.black.opacity(0.85)
						.edgesIgnoringSafeArea(.all)
					VStack(spacing: AppSpacing.regular) {
						ActivityIndicator(isAnimating: $viewModel.isConnecting, style: .large, tint: .white)
						Text(viewModel.waitingForApproval ? "Waiting for \(viewModel.connectingToName) to approve you..." : viewModel.retryingConnect ? "\(viewModel.connectingToName) didn't answer, trying again..." : "Requesting connection to \(viewModel.connectingToName)...")
							.font(.body.weight(.medium))
							.foregroundColor(.white)
							.multilineTextAlignment(.center)
							.padding(.horizontal)
						Button(action: viewModel.cancelConnection) {
							Text("Cancel")
								.font(.body.weight(.semibold))
						}
						.buttonStyle(SubtleButtonStyle())
						.padding(.top, 4)
						if SettingsStore.shared.showConnectionLog {
							ConnectionLogPanel()
						}
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				}
			}
		}
		.foregroundColor(Color("Foreground"))
	}
}

// MARK: - Hosts Page

private struct HostsPage: View {
	@ObservedObject var viewModel: MainViewModel
	@Environment(\.horizontalSizeClass) private var hSize

	/// One column in compact width (outer display / regular iPhone),
	/// two columns in regular width (inner display) — an even split that
	/// stays clean as the device folds.
	private var columns: [GridItem] {
		if hSize == .regular {
			return [GridItem(.flexible(), spacing: AppSpacing.regular), GridItem(.flexible(), spacing: AppSpacing.regular)]
		}
		return [GridItem(.flexible())]
	}

	var body: some View {
		ScrollView {
			VStack(spacing: AppSpacing.regular) {
				if viewModel.sessionExpired {
					BannerView(message: "Your Parsec session expired", actionTitle: "Sign In", action: viewModel.logout)
				}
				if let refreshError = viewModel.refreshError {
					BannerView(message: refreshError, actionTitle: "Retry", action: viewModel.refreshHosts)
				}

				if viewModel.isRefreshing {
					HStack(spacing: 8) {
						ActivityIndicator(isAnimating: $viewModel.isRefreshing, style: .medium, tint: UIColor(named: "Foreground") ?? .white)
							.frame(width: 20, height: 20)
						Text("Refreshing hosts...")
							.font(.subheadline)
							.foregroundColor(Color("Foreground"))
					}
				} else if !viewModel.refreshTime.isEmpty {
					Text(viewModel.refreshTime)
						.font(.footnote)
						.multilineTextAlignment(.center)
						.opacity(0.5)
				}

				if let lastHost = viewModel.lastHostShown, !viewModel.isConnecting {
					LastHostCard(hostname: lastHost, onReconnect: { viewModel.reconnectLastHost() }, onClear: { viewModel.clearLastHost() })
				}

				LazyVGrid(columns: columns, spacing: AppSpacing.regular) {
					ForEach(viewModel.hosts) { host in
						HostCard(host: host, onConnect: { viewModel.connectTo(host) })
					}
				}
			}
			.padding()
		}
	}
}

// MARK: - Friends Page

private struct FriendsPage: View {
	@ObservedObject var viewModel: MainViewModel

	var body: some View {
		ScrollView {
			VStack(spacing: AppSpacing.regular) {
				if let user = viewModel.userInfo {
					VStack(spacing: AppSpacing.tight) {
						Text("You")
							.font(.footnote)
							.opacity(0.5)
						URLImage(url: URL(string: "https://parsecusercontent.com/cors-resize-image/w=48,h=48,fit=crop,background=white,q=90,f=jpeg/avatars/\(String(user.id))/avatar"),
							output:
							{
								$0
									.resizable()
									.aspectRatio(contentMode: .fit)
									.frame(width: 48, height: 48)
									.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
							},
							placeholder:
							{
								Image("IconTransparent")
									.resizable()
									.aspectRatio(contentMode: .fit)
									.frame(width: 48, height: 48)
									.background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color("BackgroundPrompt")))
							})
						Text("\(user.username)#\(String(user.id))")
							.font(.body.weight(.medium))
					}
					.glassCard(fallbackFill: Color("BackgroundCard"))
				}

				if viewModel.friends.count > 0 {
					Text("Friends")
						.font(.footnote)
						.opacity(0.5)
					ForEach(viewModel.friends) { friend in
						FriendRow(friend: friend)
					}
				}
			}
			.padding()
		}
	}
}

struct MainView_Previews: PreviewProvider {
	static var previews: some View {
		MainView(nil, viewModel: MainViewModel())
	}
}
