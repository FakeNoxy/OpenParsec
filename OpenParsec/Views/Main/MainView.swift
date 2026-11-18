import SwiftUI
import ParsecSDK

struct MainView: View {
	var controller: ContentView?
	@ObservedObject var viewModel: MainViewModel

	@State private var page: Page = .hosts
	@State var inSettings: Bool = false

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
			Rectangle()
				.fill(Color("BackgroundTab"))
				.edgesIgnoringSafeArea(.all)
			Rectangle()
				.fill(Color("BackgroundGray"))
				.padding(.vertical, 52)

			// Main controls
			VStack {
				// Navigation controls
				HStack {
					Button(action: { showLogoutAlert = true }, label: { Image("SymbolExit").scaleEffect(x: -1) })
						.padding()
						.alert(isPresented: $showLogoutAlert) {
							Alert(title: Text("Are you sure you want to logout?"), primaryButton: .destructive(Text("Logout"), action: viewModel.logout), secondaryButton: .cancel(Text("Cancel")))
						}
					Spacer()
					HStack {
						if page == .hosts {
							// Probably not the best solution for equal spacing, but I don't know how to do math properly in SwiftUI. Please send me an issue if you have a better solution.
							Image(systemName: "arrow.clockwise")
								.padding(4)
								.opacity(0)

							Text(viewModel.hostCountStr)
								.multilineTextAlignment(.center)
								.foregroundColor(Color("Foreground"))
								.font(.system(size: 20, weight: .medium))
							Button(action: viewModel.refreshHosts, label: { Image(systemName: "arrow.clockwise") })
								.padding(4)
								.disabled(viewModel.isRefreshing)
								.opacity(viewModel.isRefreshing ? 0.4 : 1)
						} else if page == .friends {
							Text(viewModel.friendCountStr)
								.multilineTextAlignment(.center)
								.foregroundColor(Color("Foreground"))
								.font(.system(size: 20, weight: .medium))
						}
					}
					Spacer()
					Button(action: { withAnimation(.easeInOut(duration: 0.24)) { inSettings = true } }, label: { Image(systemName: "gear") })
						.padding()
				}
				.foregroundColor(Color("AccentColor"))
				.background(Color("BackgroundTab")
					.frame(height: 52)
					.shadow(color: Color("Shading"), radius: 4, y: 6)
					.mask(Rectangle().frame(height: 80).offset(y: 50))
				)
				.zIndex(1)

				ZStack {
					// Hosts page
					ScrollView(.vertical) {
						VStack {
							if viewModel.sessionExpired {
								HStack {
									Text("Your Parsec session expired")
										.foregroundColor(Color("Foreground"))
									Spacer()
									Button(action: viewModel.logout) {
										Text("Sign In")
											.fontWeight(.semibold)
											.foregroundColor(Color("AccentColor"))
											.frame(minWidth: 44, minHeight: 44)
											.contentShape(Rectangle())
									}
								}
								.padding(.horizontal, 12)
								.padding(.vertical, 2)
								.background(Rectangle().fill(Color("BackgroundPrompt")))
								.cornerRadius(8)
								.frame(maxWidth: 400)
								.padding(.horizontal)
							}
							if let refreshError = viewModel.refreshError {
								HStack {
									Text(refreshError)
										.foregroundColor(Color("Foreground"))
									Spacer()
									Button(action: viewModel.refreshHosts) {
										Text("Retry")
											.fontWeight(.semibold)
											.foregroundColor(Color("AccentColor"))
											.frame(minWidth: 44, minHeight: 44)
											.contentShape(Rectangle())
									}
								}
								.padding(.horizontal, 12)
								.padding(.vertical, 2)
								.background(Rectangle().fill(Color("BackgroundPrompt")))
								.cornerRadius(8)
								.frame(maxWidth: 400)
								.padding(.horizontal)
							}
							if viewModel.isRefreshing {
								HStack(spacing: 8) {
									ActivityIndicator(isAnimating: $viewModel.isRefreshing, style: .medium, tint: UIColor(named: "Foreground") ?? .white)
										.frame(width: 20, height: 20)
									Text("Refreshing hosts...")
										.foregroundColor(Color("Foreground"))
								}
							} else if !viewModel.refreshTime.isEmpty {
								Text(viewModel.refreshTime)
									.multilineTextAlignment(.center)
									.opacity(0.5)
							}
							if let lastHost = viewModel.lastHostShown, !viewModel.isConnecting {
								VStack(spacing: 0) {
									HStack {
										VStack(alignment: .leading, spacing: 4) {
											Text("Last connected")
												.font(.system(size: 12))
												.opacity(0.5)
											Text(lastHost)
												.font(.system(size: 16, weight: .medium))
										}
										Spacer()
										Button(action: viewModel.reconnectLastHost) {
											Text("Reconnect")
												.lineLimit(1)
												.fixedSize()
												.foregroundColor(.white)
												.padding(.horizontal, 16)
												.frame(minHeight: 44)
												.background(Color("AccentColor"))
												.cornerRadius(8)
										}
										Button(action: viewModel.clearLastHost) {
											Image(systemName: "xmark")
												.foregroundColor(Color("Foreground"))
												.opacity(0.5)
												.frame(width: 44, height: 44)
												.contentShape(Rectangle())
										}
									}
									.padding()
									HStack {
										Toggle("Reconnect on app launch", isOn: Binding(
											get: { SettingsStore.shared.autoConnectOnLaunch },
											set: { SettingsStore.shared.autoConnectOnLaunch = $0 }
										))
										.font(.system(size: 13))
										.opacity(0.7)
									}
									.padding(.horizontal)
									.padding(.bottom, 10)
								}
								.frame(maxWidth: 400)
								.background(Rectangle().fill(Color("BackgroundCard")))
								.cornerRadius(8)
							}
							ForEach(viewModel.hosts) { i in
								ZStack {
									VStack {
										URLImage(url: URL(string: "https://parsecusercontent.com/cors-resize-image/w=64,h=64,fit=crop,background=white,q=90,f=jpeg/avatars/\(String(i.user.id))/avatar"),
												output:
												{
													$0
														.resizable()
														.aspectRatio(contentMode: .fit)
														.frame(width: 64, height: 64)
														.cornerRadius(8)
												},
												placeholder:
												{
													Image("IconTransparent")
														.resizable()
														.aspectRatio(contentMode: .fit)
														.frame(width: 64, height: 64)
														.background(Rectangle().fill(Color("BackgroundPrompt")))
														.cornerRadius(8)
												})
										Text(i.hostname)
											.font(.system(size: 20, weight: .medium))
											.multilineTextAlignment(.center)
										Text("\(i.user.name)#\(String(i.user.id))")
											.font(.system(size: 16, weight: .medium))
											.multilineTextAlignment(.center)
											.opacity(0.5)
										Button(action: { viewModel.connectTo(i) }) {
											Text("Connect")
												.lineLimit(1)
												.fixedSize()
												.foregroundColor(.white)
												.padding(.horizontal, 28)
												.frame(minHeight: 44)
												.background(Color("AccentColor"))
												.cornerRadius(8)
										}
									}

									if i.connections > 0 {
										VStack {
											HStack {
												Image(systemName: "person.fill")
												Text(String(i.connections))
													.font(.system(size: 16, weight: .medium))
												Spacer()
											}
											Spacer()
										}
									}
								}
								.padding()
								.frame(maxWidth: 400)
								.background(Rectangle().fill(Color("BackgroundCard")))
								.cornerRadius(8)
								.contextMenu {
									Button(action: { UIPasteboard.general.string = i.hostname }) {
										Label("Copy Name", systemImage: "doc.on.doc")
									}
								}
							}
						}
						.padding()
					}
					.zIndex(page == .hosts ? 0 : -1)
					.disabled(page != .hosts)
					.opacity(page == .hosts ? 1 : 0)

					// Friends page
					ScrollView(.vertical) {
						VStack {
							if let user = viewModel.userInfo {
								Text("You")
									.multilineTextAlignment(.center)
									.opacity(0.5)
								HStack {
									URLImage(url: URL(string: "https://parsecusercontent.com/cors-resize-image/w=48,h=48,fit=crop,background=white,q=90,f=jpeg/avatars/\(String(user.id))/avatar"),
										output:
										{
											$0
												.resizable()
												.aspectRatio(contentMode: .fit)
												.frame(width: 48, height: 48)
												.cornerRadius(6)
										},
										placeholder:
										{
											Image("IconTransparent")
												.resizable()
												.aspectRatio(contentMode: .fit)
												.frame(width: 48, height: 48)
												.background(Rectangle().fill(Color("BackgroundPrompt")))
												.cornerRadius(6)
										})
									Text("\(user.username)#\(String(user.id))")
										.font(.system(size: 16, weight: .medium))
										.multilineTextAlignment(.center)
									Spacer()
								}
								.padding(8)
								.background(Color("BackgroundCard"))
								.cornerRadius(12)
							}
							if viewModel.friends.count > 0 {
								Text("Friends")
									.multilineTextAlignment(.center)
									.opacity(0.5)
								ForEach(viewModel.friends) { i in
									HStack {
										URLImage(url: URL(string: "https://parsecusercontent.com/cors-resize-image/w=48,h=48,fit=crop,background=white,q=90,f=jpeg/avatars/\(String(i.id))/avatar"),
											output:
											{
												$0
													.resizable()
													.aspectRatio(contentMode: .fit)
													.frame(width: 48, height: 48)
													.cornerRadius(6)
											},
											placeholder:
											{
												Image("IconTransparent")
													.resizable()
													.aspectRatio(contentMode: .fit)
													.frame(width: 48, height: 48)
													.background(Rectangle().fill(Color("BackgroundPrompt")))
													.cornerRadius(6)
											})
										Text("\(i.username)#\(String(i.id))")
											.font(.system(size: 16, weight: .medium))
											.multilineTextAlignment(.center)
										Spacer()
 //										Button(action:{ }, label:{ Image(systemName:"ellipsis.circle.fill") })
 //											.font(.system(size:20))
 //											.foregroundColor(Color("AccentColor"))
 //											.padding(8)
									}
									.padding(8)
									.background(Color("BackgroundCard"))
									.cornerRadius(12)
								}
							}
						}
						.padding()
					}
					.zIndex(page == .friends ? 0 : -1)
					.disabled(page != .friends)
					.opacity(page == .friends ? 1 : 0)
				}
				.padding(.top, -8)
				.frame(maxWidth: .infinity)
				.alert(isPresented: $viewModel.showBaseAlert) {
					Alert(title: Text(viewModel.baseAlertText))
				}

				// Page controls
				HStack {
					Spacer()
					Button(action: { page = .hosts }, label:
					{
						VStack {
							Image(systemName: "desktopcomputer")
							Text("Hosts")
						}
					})
					.foregroundColor(Color(page == .hosts ? "AccentColor" : "ForegroundInactive"))
					.disabled(page == .hosts)
					Spacer()
					Button(action: { page = .friends }, label:
					{
						VStack {
							Image(systemName: "person.2.fill")
							Text("Friends")
						}
					})
					.foregroundColor(Color(page == .friends ? "AccentColor" : "ForegroundInactive"))
					.disabled(page == .friends)
					Spacer()
				}
				.padding([.leading, .bottom, .trailing], 4)
				.background(Color("BackgroundTab")
					.padding(.top, -8)
					.shadow(color: Color("Shading"), radius: 4, y: -2)
					.mask(Rectangle().frame(height: 80).offset(y: -50))
				)
				.zIndex(1)
			}
			.onAppear(perform: viewModel.initView)
			.onDisappear { ParsecBackgroundManager.shared.onShortcutReconnect = nil }
			.disabled(busy) // disable view if busy

			// Settings screen
			SettingsView(visible: $inSettings)

			// Loading elements
			if viewModel.isConnecting {
				VStack(spacing: 12) {
					ActivityIndicator(isAnimating: $viewModel.isConnecting, style: .large, tint: .white)
					Text(viewModel.waitingForApproval ? "Waiting for \(viewModel.connectingToName) to approve you..." : viewModel.retryingConnect ? "\(viewModel.connectingToName) didn't answer, trying again..." : "Requesting connection to \(viewModel.connectingToName)...")
						.font(.system(size: 16, weight: .medium))
						.foregroundColor(.white)
						.multilineTextAlignment(.center)
						.padding(.horizontal)
					Button(action: viewModel.cancelConnection) {
						Text("Cancel")
							.font(.system(size: 15, weight: .semibold))
							.foregroundColor(.white)
							.padding(.horizontal, 20)
							.frame(minHeight: 44)
							.background(Color.white.opacity(0.2))
							.cornerRadius(8)
					}
					.padding(.top, 4)
					if SettingsStore.shared.showConnectionLog {
						ConnectionLogPanel()
					}
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(Color.black.opacity(0.85).edgesIgnoringSafeArea(.all))
			}
		}
		.foregroundColor(Color("Foreground"))
	}

	@State private var showLogoutAlert: Bool = false
}

struct MainView_Previews: PreviewProvider {
	static var previews: some View {
		MainView(nil, viewModel: MainViewModel())
	}
}
