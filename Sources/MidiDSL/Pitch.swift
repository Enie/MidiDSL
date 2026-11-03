import Foundation

/// A MIDI note number.
///
/// Named constants spell every pitch: `.C` to `.B` are the octave starting at middle C (`.C` is 60),
/// `.C4` and `.ASharp5` name an octave, and `Sharp` names the raised note. Notation strings
/// spell pitches as text instead. See <doc:PitchesAndDurations>.
public typealias Pitch = UInt32
public extension Pitch {
    @_documentation(visibility: internal)
    static let C: Pitch = 60
    @_documentation(visibility: internal)
    static let CSharp: Pitch = 61
    @_documentation(visibility: internal)
    static let D: Pitch = 62
    @_documentation(visibility: internal)
    static let DSharp: Pitch = 63
    @_documentation(visibility: internal)
    static let E: Pitch = 64
    @_documentation(visibility: internal)
    static let F: Pitch = 65
    @_documentation(visibility: internal)
    static let FSharp: Pitch = 66
    @_documentation(visibility: internal)
    static let G: Pitch = 67
    @_documentation(visibility: internal)
    static let GSharp: Pitch = 68
    @_documentation(visibility: internal)
    static let A: Pitch = 69
    @_documentation(visibility: internal)
    static let ASharp: Pitch = 70
    @_documentation(visibility: internal)
    static let B: Pitch = 71

    @_documentation(visibility: internal)
    static let C0: Pitch = 0
    @_documentation(visibility: internal)
    static let CSharp0: Pitch = 1
    @_documentation(visibility: internal)
    static let D0: Pitch = 2
    @_documentation(visibility: internal)
    static let DSharp0: Pitch = 3
    @_documentation(visibility: internal)
    static let E0: Pitch = 4
    @_documentation(visibility: internal)
    static let F0: Pitch = 5
    @_documentation(visibility: internal)
    static let FSharp0: Pitch = 6
    @_documentation(visibility: internal)
    static let G0: Pitch = 7
    @_documentation(visibility: internal)
    static let GSharp0: Pitch = 8
    @_documentation(visibility: internal)
    static let A0: Pitch = 9
    @_documentation(visibility: internal)
    static let ASharp0: Pitch = 10
    @_documentation(visibility: internal)
    static let B0: Pitch = 11

    @_documentation(visibility: internal)
    static let C1: Pitch = 12
    @_documentation(visibility: internal)
    static let CSharp1: Pitch = 13
    @_documentation(visibility: internal)
    static let D1: Pitch = 14
    @_documentation(visibility: internal)
    static let DSharp1: Pitch = 15
    @_documentation(visibility: internal)
    static let E1: Pitch = 16
    @_documentation(visibility: internal)
    static let F1: Pitch = 17
    @_documentation(visibility: internal)
    static let FSharp1: Pitch = 18
    @_documentation(visibility: internal)
    static let G1: Pitch = 19
    @_documentation(visibility: internal)
    static let GSharp1: Pitch = 20
    @_documentation(visibility: internal)
    static let A1: Pitch = 21
    @_documentation(visibility: internal)
    static let ASharp1: Pitch = 22
    @_documentation(visibility: internal)
    static let B1: Pitch = 23

    @_documentation(visibility: internal)
    static let C2: Pitch = 24
    @_documentation(visibility: internal)
    static let CSharp2: Pitch = 25
    @_documentation(visibility: internal)
    static let D2: Pitch = 26
    @_documentation(visibility: internal)
    static let DSharp2: Pitch = 27
    @_documentation(visibility: internal)
    static let E2: Pitch = 28
    @_documentation(visibility: internal)
    static let F2: Pitch = 29
    @_documentation(visibility: internal)
    static let FSharp2: Pitch = 30
    @_documentation(visibility: internal)
    static let G2: Pitch = 31
    @_documentation(visibility: internal)
    static let GSharp2: Pitch = 32
    @_documentation(visibility: internal)
    static let A2: Pitch = 33
    @_documentation(visibility: internal)
    static let ASharp2: Pitch = 34
    @_documentation(visibility: internal)
    static let B2: Pitch = 35

    @_documentation(visibility: internal)
    static let C3: Pitch = 36
    @_documentation(visibility: internal)
    static let CSharp3: Pitch = 37
    @_documentation(visibility: internal)
    static let D3: Pitch = 38
    @_documentation(visibility: internal)
    static let DSharp3: Pitch = 39
    @_documentation(visibility: internal)
    static let E3: Pitch = 40
    @_documentation(visibility: internal)
    static let F3: Pitch = 41
    @_documentation(visibility: internal)
    static let FSharp3: Pitch = 42
    @_documentation(visibility: internal)
    static let G3: Pitch = 43
    @_documentation(visibility: internal)
    static let GSharp3: Pitch = 44
    @_documentation(visibility: internal)
    static let A3: Pitch = 45
    @_documentation(visibility: internal)
    static let ASharp3: Pitch = 46
    @_documentation(visibility: internal)
    static let B3: Pitch = 47

    @_documentation(visibility: internal)
    static let C4: Pitch = 48
    @_documentation(visibility: internal)
    static let CSharp4: Pitch = 49
    @_documentation(visibility: internal)
    static let D4: Pitch = 50
    @_documentation(visibility: internal)
    static let DSharp4: Pitch = 51
    @_documentation(visibility: internal)
    static let E4: Pitch = 52
    @_documentation(visibility: internal)
    static let F4: Pitch = 53
    @_documentation(visibility: internal)
    static let FSharp4: Pitch = 54
    @_documentation(visibility: internal)
    static let G4: Pitch = 55
    @_documentation(visibility: internal)
    static let GSharp4: Pitch = 56
    @_documentation(visibility: internal)
    static let A4: Pitch = 57
    @_documentation(visibility: internal)
    static let ASharp4: Pitch = 58
    @_documentation(visibility: internal)
    static let B4: Pitch = 59

    @_documentation(visibility: internal)
    static let C5: Pitch = 60
    @_documentation(visibility: internal)
    static let CSharp5: Pitch = 61
    @_documentation(visibility: internal)
    static let D5: Pitch = 62
    @_documentation(visibility: internal)
    static let DSharp5: Pitch = 63
    @_documentation(visibility: internal)
    static let E5: Pitch = 64
    @_documentation(visibility: internal)
    static let F5: Pitch = 65
    @_documentation(visibility: internal)
    static let FSharp5: Pitch = 66
    @_documentation(visibility: internal)
    static let G5: Pitch = 67
    @_documentation(visibility: internal)
    static let GSharp5: Pitch = 68
    @_documentation(visibility: internal)
    static let A5: Pitch = 69
    @_documentation(visibility: internal)
    static let ASharp5: Pitch = 70
    @_documentation(visibility: internal)
    static let B5: Pitch = 71

    @_documentation(visibility: internal)
    static let C6: Pitch = 72
    @_documentation(visibility: internal)
    static let CSharp6: Pitch = 73
    @_documentation(visibility: internal)
    static let D6: Pitch = 74
    @_documentation(visibility: internal)
    static let DSharp6: Pitch = 75
    @_documentation(visibility: internal)
    static let E6: Pitch = 76
    @_documentation(visibility: internal)
    static let F6: Pitch = 77
    @_documentation(visibility: internal)
    static let FSharp6: Pitch = 78
    @_documentation(visibility: internal)
    static let G6: Pitch = 79
    @_documentation(visibility: internal)
    static let GSharp6: Pitch = 80
    @_documentation(visibility: internal)
    static let A6: Pitch = 81
    @_documentation(visibility: internal)
    static let ASharp6: Pitch = 82
    @_documentation(visibility: internal)
    static let B6: Pitch = 83

    @_documentation(visibility: internal)
    static let C7: Pitch = 84
    @_documentation(visibility: internal)
    static let CSharp7: Pitch = 85
    @_documentation(visibility: internal)
    static let D7: Pitch = 86
    @_documentation(visibility: internal)
    static let DSharp7: Pitch = 87
    @_documentation(visibility: internal)
    static let E7: Pitch = 88
    @_documentation(visibility: internal)
    static let F7: Pitch = 89
    @_documentation(visibility: internal)
    static let FSharp7: Pitch = 90
    @_documentation(visibility: internal)
    static let G7: Pitch = 91
    @_documentation(visibility: internal)
    static let GSharp7: Pitch = 92
    @_documentation(visibility: internal)
    static let A7: Pitch = 93
    @_documentation(visibility: internal)
    static let ASharp7: Pitch = 94
    @_documentation(visibility: internal)
    static let B7: Pitch = 95

    @_documentation(visibility: internal)
    static let C8: Pitch = 96
    @_documentation(visibility: internal)
    static let CSharp8: Pitch = 97
    @_documentation(visibility: internal)
    static let D8: Pitch = 98
    @_documentation(visibility: internal)
    static let DSharp8: Pitch = 99
    @_documentation(visibility: internal)
    static let E8: Pitch = 100
    @_documentation(visibility: internal)
    static let F8: Pitch = 101
    @_documentation(visibility: internal)
    static let FSharp8: Pitch = 102
    @_documentation(visibility: internal)
    static let G8: Pitch = 103
    @_documentation(visibility: internal)
    static let GSharp8: Pitch = 104
    @_documentation(visibility: internal)
    static let A8: Pitch = 105
    @_documentation(visibility: internal)
    static let ASharp8: Pitch = 106
    @_documentation(visibility: internal)
    static let B8: Pitch = 107

    @_documentation(visibility: internal)
    static let C9: Pitch = 108
    @_documentation(visibility: internal)
    static let CSharp9: Pitch = 109
    @_documentation(visibility: internal)
    static let D9: Pitch = 110
    @_documentation(visibility: internal)
    static let DSharp9: Pitch = 111
    @_documentation(visibility: internal)
    static let E9: Pitch = 112
    @_documentation(visibility: internal)
    static let F9: Pitch = 113
    @_documentation(visibility: internal)
    static let FSharp9: Pitch = 114
    @_documentation(visibility: internal)
    static let G9: Pitch = 115
    @_documentation(visibility: internal)
    static let GSharp9: Pitch = 116
    @_documentation(visibility: internal)
    static let A9: Pitch = 117
    @_documentation(visibility: internal)
    static let ASharp9: Pitch = 118
    @_documentation(visibility: internal)
    static let B9: Pitch = 119

    @_documentation(visibility: internal)
    static let C10: Pitch = 120
    @_documentation(visibility: internal)
    static let CSharp10: Pitch = 121
    @_documentation(visibility: internal)
    static let D10: Pitch = 122
    @_documentation(visibility: internal)
    static let DSharp10: Pitch = 123
    @_documentation(visibility: internal)
    static let E10: Pitch = 124
    @_documentation(visibility: internal)
    static let F10: Pitch = 125
    @_documentation(visibility: internal)
    static let FSharp10: Pitch = 126
    @_documentation(visibility: internal)
    static let G10: Pitch = 127
}
