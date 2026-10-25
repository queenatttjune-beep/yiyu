import Foundation
import Testing
@testable import YiyuCore

struct WritingStyleTests {
    @Test func builtInStylesComeFirstInAFixedOrder() {
        #expect(WritingStyle.builtIns.map(\.name) == ["白描", "诗意", "华丽"])
        #expect(WritingStyle.builtIns.allSatisfy { $0.isBuiltIn })
    }

    @Test func allStylesAppendCustomOnesAfterBuiltIns() {
        let custom = WritingStyle.custom(name: "汪曾祺", instruction: "像汪曾祺那样平淡有味", id: "c1")
        let all = WritingStyle.all(custom: [custom])
        #expect(all.map(\.name) == ["白描", "诗意", "华丽", "汪曾祺"])
        #expect(!all[3].isBuiltIn)
    }

    @Test func addingTrimsAndRejectsBlankOrDuplicateNames() {
        let added = StyleBook.adding(name: " 第三人称 ", instruction: " 改成第三人称叙述 ", to: [], id: "c1")
        #expect(added.map(\.name) == ["第三人称"])
        #expect(added[0].instruction == "改成第三人称叙述")
        #expect(StyleBook.adding(name: "  ", instruction: "x", to: added, id: "c2") == added)
        #expect(StyleBook.adding(name: "x", instruction: "  ", to: added, id: "c2") == added)
        #expect(StyleBook.adding(name: "第三人称", instruction: "别的", to: added, id: "c2") == added)
        #expect(StyleBook.adding(name: "诗意", instruction: "重名", to: added, id: "c2") == added)
    }

    @Test func removingDropsOnlyThatStyle() {
        let styles = StyleBook.adding(name: "甲", instruction: "a", to: StyleBook.adding(name: "乙", instruction: "b", to: [], id: "b"), id: "a")
        #expect(StyleBook.removing("b", from: styles).map(\.name) == ["甲"])
    }
}
