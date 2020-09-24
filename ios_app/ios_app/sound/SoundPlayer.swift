import Foundation
import AudioToolbox

enum Sound {
    // 0 - 11 (clock directions)
    case dir0
    case dir1
    case dir2
    case dir3
    case dir4
    case dir5
    case dir6
    case dir7
    case dir8
    case dir9
    case dir10
    case dir11

    // 0 - 100 (10 meter steps)
    case dist0
    case dist1
    case dist2
    case dist3
    case dist4
    case dist5
    case dist6
    case dist7
    case dist8
    case dist9
}

protocol SoundPlayer {
    func play(sound: Sound)
}

class SoundPlayerImpl: SoundPlayer {

    func play(sound: Sound) {
//        let name = fileName(sound: sound)
//        guard let filePath = Bundle.main.path(forResource: name, ofType: "mp3") else {
//            fatalError("Sound file not present: \(name)")
//        }
//
//        var soundID: SystemSoundID = 0
//        let url = NSURL(fileURLWithPath: filePath)
//        AudioServicesCreateSystemSoundID(url, &soundID)
//        AudioServicesPlaySystemSound(soundID)
    }

    private func fileName(sound: Sound) -> String {
        switch sound {
        case .dir0: return "dir0"
        case .dir1: return "dir1"
        case .dir2: return "dir2"
        case .dir3: return "dir3"
        case .dir4: return "dir4"
        case .dir5: return "dir5"
        case .dir6: return "dir6"
        case .dir7: return "dir7"
        case .dir8: return "dir8"
        case .dir9: return "dir9"
        case .dir10: return "dir10"
        case .dir11: return "dir11"
            
        case .dist0: return "dist0"
        case .dist1: return "dist1"
        case .dist2: return "dist2"
        case .dist3: return "dist3"
        case .dist4: return "dist4"
        case .dist5: return "dist5"
        case .dist6: return "dist6"
        case .dist7: return "dist7"
        case .dist8: return "dist8"
        case .dist9: return "dist9"
        }
    }
}
