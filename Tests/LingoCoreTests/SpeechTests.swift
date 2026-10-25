import AVFoundation
import Foundation
import Testing
@testable import LingoCore

@Suite struct TurnSegmenterTests {
    @Test func pauseShorterThanTKeepsOneUtterance() {
        let spans = TurnTimeline.run([.speech(1500), .silence(1400), .speech(800), .silence(3000)])
        #expect(spans.count == 1)
        #expect(abs(spans[0].end - 3.7) < 0.05)
    }

    @Test func s05AdditionWithinGMerges() {
        var seg = TurnSegmenter()
        _ = seg.speechStarted(at: 0)
        _ = seg.speechEnded(at: 1.3)
        #expect(seg.advance(to: 2.8) == [.utterance(.init(start: 0, end: 1.3))])
        #expect(seg.speechStarted(at: 3.1) == [.speechBegan(at: 3.1, mergesWithPrevious: true)])
        _ = seg.speechEnded(at: 3.7)
        #expect(seg.advance(to: 5.3) == [.merged(previous: .init(start: 0, end: 1.3), span: .init(start: 0, end: 3.7))])
    }

    @Test func noMergeAfterAssistantStarted() {
        var seg = TurnSegmenter()
        _ = seg.speechStarted(at: 0); _ = seg.speechEnded(at: 1.0); _ = seg.advance(to: 2.6)
        seg.assistantStartedSpeaking()
        #expect(seg.speechStarted(at: 2.8) == [.speechBegan(at: 2.8, mergesWithPrevious: false)])
    }

    @Test func shortNoiseDiscarded() {
        var seg = TurnSegmenter()
        _ = seg.speechStarted(at: 0); _ = seg.speechEnded(at: 0.15)
        #expect(seg.advance(to: 2) == [.discarded(.init(start: 0, end: 0.15))])
    }

    @Test func flushEndsImmediately() {
        var seg = TurnSegmenter()
        _ = seg.speechStarted(at: 0)
        #expect(seg.flush(at: 1.0) == [.utterance(.init(start: 0, end: 1.0))])
    }

    @Test func configRanges() {
        #expect(TurnConfig(silence: 9).silence == 3.0)
        #expect(TurnConfig(silence: 0.1).silence == 0.6)
        #expect(TurnConfig(mergeGap: 7).mergeGap == 4)
    }
}

@Suite struct CommandDetectorTests {
    @Test func basics() {
        #expect(CommandDetector.detect("nochmal, bitte")?.kind == .repeatLast)
        #expect(CommandDetector.detect("А можно медленнее?")?.kind == .slower)
        #expect(CommandDetector.detect("Как сказать «у меня сейчас каникулы»?") == CommandMatch(.howToSay, argument: "у меня сейчас каникулы"))
        #expect(CommandDetector.detect("Nein, machen wir weiter")?.kind == .continuePractice)
        #expect(CommandDetector.detect("any mistakes?")?.kind == .mistakes)
        #expect(CommandDetector.detect("das war's")?.kind == .finish)
        #expect(CommandDetector.detect("Langsam wird es kalt") == nil)
        #expect(CommandDetector.detect("Я вчера повторил весь урок") == nil)
        #expect(CommandDetector.detect("Как сказал мой друг, Гамбург красивый") == nil)
        #expect(CommandDetector.detect("") == nil)
    }

    @Test func asrTypos() {
        #expect(CommandDetector.detect("langsammer")?.kind == .slower)
        #expect(CommandDetector.detect("повтор и")?.kind == .repeatLast)
    }
}

@Suite struct SpeechUtilTests {
    @Test func slowChunksSplitByPunctuationAndGroups() {
        let c = SlowChunks.split("Hi, I'm Alex. Nice to meet you.")
        #expect(c == ["Hi,", "I'm Alex.", "Nice to meet you."])
        let long = SlowChunks.split("Ich wohne seit zwei Jahren in Hamburg und arbeite dort als Entwickler")
        #expect(long.count >= 3)
        #expect(long.joined(separator: " ") == "Ich wohne seit zwei Jahren in Hamburg und arbeite dort als Entwickler")
        #expect(SpeechPace.slowSteps == [1.0, 0.75, 0.6])
    }

    @Test func werAndScript() {
        #expect(WER.compute(ref: "Ich wohne in Hamburg.", hyp: "ich wohne in hamburg") == 0)
        #expect(abs(WER.compute(ref: "a b c d", hyp: "a x c") - 0.5) < 1e-9)
        #expect(WhisperEngine.scriptLang("Нет, я хочу сказать", candidates: [.de, .ru]) == .ru)
        #expect(WhisperEngine.scriptLang("Ich habe Ferien. Подожди", candidates: [.de, .ru]) == .de)
        #expect(WhisperEngine.scriptLang("…", candidates: [.de, .ru]) == nil)
    }

    @Test func utteranceBufferCapsAt60s() {
        var b = UtteranceBuffer()
        b.append([Float](repeating: 0.1, count: 16_000 * 61))
        #expect(b.seconds == 60)
    }

    @Test func modelStoreClonesAndChecksSHA() async throws {
        let src = tempDir("src"), dst = tempDir("dst")
        let data = Data("synthetic model bytes".utf8)
        try data.write(to: src.appendingPathComponent("m.bin"))
        let sha = try ModelStore.sha256(of: src.appendingPathComponent("m.bin"))
        let m = WhisperModel(file: "m.bin", title: "t", size: Int64(data.count), sha256: sha, url: URL(string: "https://invalid.example/m.bin")!)
        let store = ModelStore(dir: dst, cloneSources: [src])
        let p = try await store.ensure(m)
        #expect(FileManager.default.fileExists(atPath: p.path) && store.isInstalled(m))
        let bad = WhisperModel(file: "m.bin", title: "t", size: 999, sha256: String(repeating: "0", count: 64), url: m.url)
        await #expect(throws: ModelStore.ModelError.self) { try await ModelStore(dir: tempDir("dst2"), cloneSources: [src]).ensure(bad) }
    }
}

@Suite struct PCMConverterTests {
    /// Voice processing на macOS отдаёт 48 кГц, 5 каналов (H-2): в 16 кГц моно должен попасть канал 0, а не тишина.
    @Test func multichannelInputKeepsFirstChannel() {
        let layout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | 5)!
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, interleaved: false, channelLayout: layout)
        let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 4800)!
        b.frameLength = 4800
        for i in 0..<4800 { b.floatChannelData![0][i] = 0.5 * sin(Float(i) / 48_000 * 2 * .pi * 440) }
        let conv = PCMConverter()
        _ = conv.convert(b) // первый буфер короче из-за задержки ресемплера
        let out = conv.convert(b)
        #expect(out.count > 1500 && out.count < 1700)
        #expect((out.map { abs($0) }.max() ?? 0) > 0.3)
    }
}
