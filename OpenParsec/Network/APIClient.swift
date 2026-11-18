import Foundation

/// Typed errors thrown by `APIClient`.
enum APIError: Error {
	/// The request failed at the transport level (no HTTP response).
	case transport(underlying: Error)
	/// The server returned a non-2xx status. `data` is the raw response body so
	/// call sites can decode `ErrorInfo` (or `tfa_required`) exactly as needed.
	case http(status: Int, data: Data)
	/// The response body could not be decoded into the expected type.
	case decoding(underlying: Error)
}

/// Convenience accessors over `APIError`.
extension APIError {
	/// Decodes the body of an `.http` error as `ErrorInfo`, if present.
	var errorInfo: ErrorInfo? {
		guard case .http(_, let data) = self else { return nil }
		return try? JSONDecoder().decode(ErrorInfo.self, from: data)
	}
	/// The raw body of an `.http` error, if any.
	var rawBody: Data? {
		guard case .http(_, let data) = self else { return nil }
		return data
	}
}

/// A successful HTTP response: the decoded body plus the status code,
/// so call sites can branch on status exactly as the old inline code did.
struct APIResponse<T> {
	let status: Int
	let data: T
}

/// Single source of truth for Parsec API requests (base URL, User-Agent, headers).
struct APIClient {
	static let shared = APIClient()

	let baseURL = AppConstants.apiBaseURL
	let userAgent = AppConstants.userAgent

	/// Performs a request and returns the raw body (no decoding).
	/// Throws `APIError.http` for non-2xx responses (carrying the raw body).
	func raw(_ path: String, method: String = "GET", body: Any? = nil, auth: Bool = true) async throws -> (status: Int, data: Data) {
		let (data, http) = try await perform(path: path, method: method, body: body, auth: auth)
		guard http.statusCode < 400 else {
			throw APIError.http(status: http.statusCode, data: data)
		}
		return (http.statusCode, data)
	}

	/// Performs a request and decodes the JSON body into `T`.
	/// Throws `APIError.http` for non-2xx responses (carrying the raw body).
	func data<T: Decodable>(_ path: String, method: String = "GET", body: Any? = nil, auth: Bool = true) async throws -> APIResponse<T> {
		let (data, http) = try await perform(path: path, method: method, body: body, auth: auth)
		guard http.statusCode < 400 else {
			throw APIError.http(status: http.statusCode, data: data)
		}
		do {
			let decoded = try JSONDecoder().decode(T.self, from: data)
			return APIResponse(status: http.statusCode, data: decoded)
		} catch {
			throw APIError.decoding(underlying: error)
		}
	}

	private func perform(path: String, method: String, body: Any?, auth: Bool) async throws -> (data: Data, http: HTTPURLResponse) {
		// Build the URL without percent-encoding the query string:
		// `appendingPathComponent` would encode `?`/`&`/`=` in paths like "v2/hosts?mode=desktop&public=false".
		let url: URL
		if let queryRange = path.range(of: "?") {
			let pathPart = String(path[..<queryRange.lowerBound])
			let queryPart = String(path[path.index(after: queryRange.lowerBound)...])
			var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
			comps.path = comps.path.hasSuffix("/") ? pathPart : comps.path + "/" + pathPart
			comps.query = queryPart
			guard let built = comps.url else { throw APIError.transport(underlying: NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)) }
			url = built
		} else {
			url = baseURL.appendingPathComponent(path)
		}
		var request = URLRequest(url: url)
		request.httpMethod = method
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
		if auth, let session = SessionStore.clinfo {
			request.setValue("Bearer \(session.session_id)", forHTTPHeaderField: "Authorization")
		}
		if let body = body {
			request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
		}

		let (data, response): (Data, URLResponse)
		do {
			(data, response) = try await URLSession.shared.data(for: request)
		} catch {
			throw APIError.transport(underlying: error)
		}

		guard let http = response as? HTTPURLResponse else {
			throw APIError.transport(underlying: NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo: [NSLocalizedDescriptionKey: "Bad response from the server"]))
		}

		return (data, http)
	}
}
