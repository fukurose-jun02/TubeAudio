import Foundation

import Observation

struct VideoInfo: Decodable {
    let title: String
    let thumbnail: String
    let channel: String
    let channel_icon: String?
    let duration_str: String
}

struct SearchResult: Decodable, Identifiable {
    let video_id: String
    let url: String
    let title: String
    let channel: String
    let thumbnail: String

    var id: String { video_id }
}

struct JobStatus: Decodable {
    let status: String
    let progress: Int?
    let title: String?
    let filename: String?
    let filesize: String?
    let error: String?
    let channel: String?
    let duration: Double?
    let upload_date: String?
    let view_count: Int?
}

@Observable
class APIClient {
    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }

    init() {
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://fukuroseatsushinomacbook-air.local:5001"
    }

    func search(query: String) async throws -> [SearchResult] {
        var comps = URLComponents(string: "\(serverURL)/api/search")!
        comps.queryItems = [URLQueryItem(name: "q", value: query)]
        let (data, response) = try await URLSession.shared.data(from: comps.url!)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw NSError(domain: "", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message ?? "検索に失敗しました"])
        }
        struct Wrapper: Decodable { let results: [SearchResult] }
        return try JSONDecoder().decode(Wrapper.self, from: data).results
    }

    func fetchInfo(url: String) async throws -> VideoInfo {
        var req = URLRequest(url: URL(string: "\(serverURL)/api/info")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["url": url])
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(VideoInfo.self, from: data)
    }

    func startConvert(url: String, format: String, quality: String) async throws -> String {
        var req = URLRequest(url: URL(string: "\(serverURL)/api/convert")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["url": url, "format": format, "quality": quality])
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONDecoder().decode([String: String].self, from: data)
        guard let jobId = json["job_id"] else { throw URLError(.badServerResponse) }
        return jobId
    }

    func pollStatus(jobId: String) async throws -> JobStatus {
        let url = URL(string: "\(serverURL)/api/status/\(jobId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(JobStatus.self, from: data)
    }

    func downloadFile(jobId: String, filename: String) async throws -> URL {
        let url = URL(string: "\(serverURL)/api/download/\(jobId)")!
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }
}
