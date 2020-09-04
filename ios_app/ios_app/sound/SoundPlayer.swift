import Foundation
import AudioToolbox

enum Sound {
    case dir0 // 0 - 11
    case dist0 // 0 - 10
}

protocol SoundPlayer {
    func play(sound: Sound)
}

class SoundPlayerImpl: SoundPlayer {

    func play(sound: Sound) {
        let name = fileName(sound: sound)
        guard let filePath = Bundle.main.path(forResource: name, ofType: "mp3") else {
            fatalError("Sound file not present: \(name)")
        }

        var soundID: SystemSoundID = 0
        let url = NSURL(fileURLWithPath: filePath)
        AudioServicesCreateSystemSoundID(url, &soundID)
        AudioServicesPlaySystemSound(soundID)
    }

    private func fileName(sound: Sound) -> String {
        switch sound {
        case .dir0: return "dir0"
        case .dist0: return "dist0"
        }
    }
}
