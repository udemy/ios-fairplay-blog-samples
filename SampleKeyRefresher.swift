import AVFoundation

final class SampleKeyRefresher: AVContentKeySessionDelegate { 
    
    let session: AVContentKeySession = AVContentKeySession(keySystem: .fairPlayStreaming)
    let queue = DispatchQueue(label: "fairplay.refresher.queue")
    // Certificate data, fetch from remote or cache locally
    let certificateData: Data = Data(contentsOf: URL(string: "https://sample.certificate.url")!)
    // Key server url
    let keyServerUrl: URL = URL(string: "https://key.server.url")
    let logger = Logger()
    
    private enum DelegateError: Error {
        case noContentId
        case noCertificateData
        case noSPCData
        case ckcFetch
    }
    
    func refresh(contentId: Data) {
        session.setDelegate(self, queue: self.queue)
        session.processContentKeyRequest(withIdentifier: contentId, initializationData: nil, options: nil)   
    }
    
    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        do {
            logger.debug("Redirecting to persistable content key request")
            try keyRequest.respondByRequestingPersistableContentKeyRequestAndReturnError()
        } catch {
            logger.error("Unable to respond by persistable content key request \(error).")
            keyRequest.processContentKeyResponseError(error)
        }
    }
    
    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVPersistableContentKeyRequest) {
        logger.debug("Start persistable content key request")
        // We first check if a url is set in the manifest.
        guard let contentId = keyRequest.identifier as? String, let contentIdData = contentId.data(using: String.Encoding.utf8) else {
            logger.error("Unable to read contentId.")
            keyRequest.processContentKeyResponseError(DelegateError.noContentId)
            return
        }
        
        keyRequest.makeStreamingContentKeyRequestData(forApp: certificateData, contentIdentifier: contentIdData, options: [AVAssetResourceLoadingRequestStreamingContentKeyRequestRequiresPersistentKey: true as AnyObject]) { spcData, spcError in
            guard let spcData = spcData else {
                let error = spcError ?? DelegateError.noSPCData
                logger.error("Unable to fetch SPC data \(error).")
                keyRequest.processContentKeyResponseError(error)
                return
            }
            logger.debug("SPC data fetched, requesting CKC")
            let stringBody: String = "spc=\(spcData.base64EncodedString())&assetId=\(contentId)"
            var ckcRequest = URLRequest(url: self.keyServerUrl)
            ckcRequest.httpMethod = HTTPMethod.post.rawValue
            ckcRequest.httpBody = stringBody.data(using: String.Encoding.utf8)
            URLSession(configuration: URLSessionConfiguration.default).dataTask(with: ckcRequest) { data, _, error in
                guard let data = data else {
                    logger.error("Error in response data in CKC request: \(error)")
                    keyRequest.processContentKeyResponseError(error)
                    return
                }
                // The CKC is correctly returned and is now send to the `AVPlayer` instance so we
                // can continue to play the stream.
                guard let ckcData = Data(base64Encoded: data) else {
                    logger.error("Can't create base64 encoded data")
                    keyRequest.processContentKeyResponseError(DelegateError.ckcFetch)
                    return
                }

                var persistentKeyData: Data?
                do {
                    persistentKeyData = try keyRequest.persistableContentKey(fromKeyVendorResponse: data, options: nil)
                } catch {
                    logger.error("Unable to create persistable content key \(error).")
                    keyRequest.processContentKeyResponseError(error)
                    return
                }
                let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: persistentKeyData)
                keyRequest.processContentKeyResponse(keyResponse)
                logger.debug("CKC received, loading complete")
            }.resume()   
        }
    }
   
    func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        do {
            logger.debug("Redirecting to persistable content key request")
            try keyRequest.respondByRequestingPersistableContentKeyRequestAndReturnError()
        } catch {
            logger.error("Unable to respond by persistable content key request \(error).")
            keyRequest.processContentKeyResponseError(error)
        }
    }
       
}

