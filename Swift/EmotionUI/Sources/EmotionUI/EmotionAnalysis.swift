import SwiftUI
import EmotionCore

public struct EmotionAnalysisView: View {
    @ObservedObject var manager: EmotionCoreManager = .shared

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text(manager.dominantEmotion.capitalized)
                .font(.largeTitle)
            if manager.emotionScores.isEmpty {
                Text("等待分析...")
                    .foregroundColor(.secondary)
            } else {
                List {
                    ForEach(manager.emotionScores.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                        HStack {
                            Text(k.capitalized)
                            Spacer()
                            Text(String(format: "%.1f%%", v * 100))
                        }
                    }
                }
            }
        }
        .padding()
    }
}

