//  Created by Martin Cardozo on 22/10/2025.

internal enum Errors: Error {
    case notImplemented
    case missingInitContext(errorCode: Int = 1)
    case missingInitData(errorCode: Int = 2)
}
