import AVFoundation

final class SampleResourceLoaderDelegate: AVAssetResourceLoaderDelegate {
   
    public enum DRMError: Error {
        case noURLFound
        case noSPCFound(underlyingError: Error?)
        case noContentIdFound
        case cannotEncodeCKCData
        case unableToGeneratePersistentKey
        case unableToFetchKey(underlyingError: Error?)
    }
    
    // Certificate data, fetch from remote or cache locally
    let certificateData: Data = Data(contentsOf: URL(string: "https://sample.certificate.url")!)
    // Key server url
    let keyServerUrl: URL = URL(string: "https://key.server.url")
    let logger = Logger()
    
    
    /// Asks the delegate if it wants to load the requested resource.
    /// - Parameters:
    ///   - resourceLoader: The resource loader object that is making the request.
    ///   - loadingRequest: The loading request object that contains information about the requested resource.
    /// - Returns: true if your delegate can load the resource specified by the loadingRequest parameter or false if it cannot.
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, 
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
     
        // We first check if a url is set in the manifest.
        guard let url = loadingRequest.request.url else {
            logger.info("Unable to read the url/host data.")
            loadingRequest.finishLoading(with: DRMError.noURLFound)
            return false
        }
        
        // Get the content id. Content id will be stored in the host of the request url
        guard let contentId = url.host, let contentIdData = contentId.data(using: String.Encoding.utf8) else {
            logger.error("Unable to read the content id.")
            loadingRequest.finishLoading(with: DRMError.noContentIdFound)
            return false
        }
        
        // Request SPC data from OS
        var _spcData: Data?
        var _spcError: Error?
        do {
            _spcData = try loadingRequest.streamingContentKeyRequestData(forApp: certificateData, contentIdentifier: contentIdData, options: [AVAssetResourceLoadingRequestStreamingContentKeyRequestRequiresPersistentKey: true as AnyObject])
        } catch {
            _spcError = error
            logger.error("Failed to get stream content key with error: \(error)")
        }

        guard let spcData = _spcData, let dataRequest = loadingRequest.dataRequest else {
            loadingRequest.finishLoading(with: DRMError.noSPCFound(underlyingError: _spcError))
            logger.error("Unable to read the SPC data.")
            return false
        }
        
        let stringBody: String = "spc=\(spcData.base64EncodedString())&assetId=\(contentId)"
        var ckcRequest = URLRequest(url: self.keyServerUrl)
        ckcRequest.httpMethod = HTTPMethod.post.rawValue
        ckcRequest.httpBody = stringBody.data(using: String.Encoding.utf8)
        URLSession(configuration: URLSessionConfiguration.default).dataTask(with: ckcRequest) { data, _, error in
            guard let data = data else {
                logger.error("Error in response data in CKC request: \(error)")
                loadingRequest.finishLoading(with: DRMError.unableToFetchKey(underlyingError: _spcError))
                return
            }
            // The CKC is correctly returned and is now send to the `AVPlayer` instance so we
            // can continue to play the stream.
            guard let ckcData = Data(base64Encoded: data) else {
                logger.error("Can't create base64 encoded data")
                loadingRequest.finishLoading(with: DRMError.cannotEncodeCKCData)
                return
            }
            // If we need non-persistent token, then complete loading
            // dataRequest.respond(with: data)
            // loadingRequest.finishLoading()
                                                                                               
            // If we need persistent token, then it is time to add persistence option
            var persistentKeyData: Data?
            do {
                persistentKeyData = try loadingRequest.persistentContentKey(fromKeyVendorResponse: ckcData, options: nil)
            } catch {
                logger.error("Failed to get persistent key with error: \(error)")
                loadingRequest.finishLoading(with: DRMError.unableToGeneratePersistentKey))
                return
            }
            // set type of the key
            loadingRequest.contentInformationRequest?.contentType = AVStreamingKeyDeliveryPersistentContentKeyType
            dataRequest.respond(with: persistentKeyData)
            loadingRequest.finishLoading()
        
        }.resume()
        return true
    }
    
}
