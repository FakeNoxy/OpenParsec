import UIKit
import ParsecSDK

// Character / string → Parsec keycode mapping.
extension KeyCodeTranslators {
	static func parsecKeyCodeTranslator(_ str: String) -> ParsecKeycode? {
		switch str {
			case "A": return ParsecKeycode(4)
			case "B": return ParsecKeycode(5)
			case "C": return ParsecKeycode(6)
			case "D": return ParsecKeycode(7)
			case "E": return ParsecKeycode(8)
			case "F": return ParsecKeycode(9)
			case "G": return ParsecKeycode(10)
			case "H": return ParsecKeycode(11)
			case "I": return ParsecKeycode(12)
			case "J": return ParsecKeycode(13)
			case "K": return ParsecKeycode(14)
			case "L": return ParsecKeycode(15)
			case "M": return ParsecKeycode(16)
			case "N": return ParsecKeycode(17)
			case "O": return ParsecKeycode(18)
			case "P": return ParsecKeycode(19)
			case "Q": return ParsecKeycode(20)
			case "R": return ParsecKeycode(21)
			case "S": return ParsecKeycode(22)
			case "T": return ParsecKeycode(23)
			case "U": return ParsecKeycode(24)
			case "V": return ParsecKeycode(25)
			case "W": return ParsecKeycode(26)
			case "X": return ParsecKeycode(27)
			case "Y": return ParsecKeycode(28)
			case "Z": return ParsecKeycode(29)
            case "Ñ": return ParsecKeycode(51)
			case "1": return ParsecKeycode(30)
			case "2": return ParsecKeycode(31)
			case "3": return ParsecKeycode(32)
			case "4": return ParsecKeycode(33)
			case "5": return ParsecKeycode(34)
			case "6": return ParsecKeycode(35)
			case "7": return ParsecKeycode(36)
			case "8": return ParsecKeycode(37)
			case "9": return ParsecKeycode(38)
			case "0": return ParsecKeycode(39)
			case "ENTER": return ParsecKeycode(40)
			case "UIKeyInputEscape": return ParsecKeycode(41) // ESCAPE with re-factored
			case "BACKSPACE": return ParsecKeycode(42)
			case "TAB": return ParsecKeycode(43)
			case "SPACE": return ParsecKeycode(44)
			case "MINUS": return ParsecKeycode(45)
			case "EQUALS": return ParsecKeycode(46)
			case "LBRACKET": return ParsecKeycode(47)
			case "RBRACKET": return ParsecKeycode(48)
			case "BACKSLASH": return ParsecKeycode(49)
			case "SEMICOLON": return ParsecKeycode(51)
			case "APOSTROPHE": return ParsecKeycode(52)
			case "BACKTICK": return ParsecKeycode(53)
			case "COMMA": return ParsecKeycode(54)
			case "PERIOD": return ParsecKeycode(55)
			case "SLASH": return ParsecKeycode(56)
			case "CAPSLOCK": return ParsecKeycode(57)
			case "F1": return ParsecKeycode(58)
			case "F2": return ParsecKeycode(59)
			case "F3": return ParsecKeycode(60)
			case "F4": return ParsecKeycode(61)
			case "F5": return ParsecKeycode(62)
			case "F6": return ParsecKeycode(63)
			case "F7": return ParsecKeycode(64)
			case "F8": return ParsecKeycode(65)
			case "F9": return ParsecKeycode(66)
			case "F10": return ParsecKeycode(67)
			case "F11": return ParsecKeycode(68)
			case "F12": return ParsecKeycode(69)
			case "PRINTSCREEN": return ParsecKeycode(70)
			case "SCROLLLOCK": return ParsecKeycode(71)
			case "PAUSE": return ParsecKeycode(72)
			case "INSERT": return ParsecKeycode(73)
			case "HOME": return ParsecKeycode(74)
			case "PAGEUP": return ParsecKeycode(75)
			case "DELETE": return ParsecKeycode(76)
			case "END": return ParsecKeycode(77)
			case "PAGEDOWN": return ParsecKeycode(78)
			case "RIGHT": return ParsecKeycode(79)
			case "LEFT": return ParsecKeycode(80)
			case "DOWN": return ParsecKeycode(81)
			case "UP": return ParsecKeycode(82)
			case "NUMLOCK": return ParsecKeycode(83)
			case "KP_DIVIDE": return ParsecKeycode(84)
			case "KP_MULTIPLY": return ParsecKeycode(85)
			case "KP_MINUS": return ParsecKeycode(86)
			case "KP_PLUS": return ParsecKeycode(87)
			case "KP_ENTER": return ParsecKeycode(88)
			case "KP_1": return ParsecKeycode(89)
			case "KP_2": return ParsecKeycode(90)
			case "KP_3": return ParsecKeycode(91)
			case "KP_4": return ParsecKeycode(92)
			case "KP_5": return ParsecKeycode(93)
			case "KP_6": return ParsecKeycode(94)
			case "KP_7": return ParsecKeycode(95)
			case "KP_8": return ParsecKeycode(96)
			case "KP_9": return ParsecKeycode(97)
			case "KP_0": return ParsecKeycode(98)
			case "KP_PERIOD": return ParsecKeycode(99)
			case "APPLICATION": return ParsecKeycode(101)
			case "F13": return ParsecKeycode(104)
			case "F14": return ParsecKeycode(105)
			case "F15": return ParsecKeycode(106)
			case "F16": return ParsecKeycode(107)
			case "F17": return ParsecKeycode(108)
			case "F18": return ParsecKeycode(109)
			case "F19": return ParsecKeycode(110)
			case "MENU": return ParsecKeycode(118)
			case "MUTE": return ParsecKeycode(127)
			case "VOLUMEUP": return ParsecKeycode(128)
			case "VOLUMEDOWN": return ParsecKeycode(129)
			case "CONTROL": return ParsecKeycode(224)
			case "SHIFT": return ParsecKeycode(225)
			case "LALT": return ParsecKeycode(226)
			case "LGUI": return ParsecKeycode(227)
			case "RCTRL": return ParsecKeycode(228)
			case "RSHIFT": return ParsecKeycode(229)
			case "RALT": return ParsecKeycode(230)
			case "RGUI": return ParsecKeycode(231)
			case "AUDIONEXT": return ParsecKeycode(258)
			case "AUDIOPREV": return ParsecKeycode(259)
			case "AUDIOSTOP": return ParsecKeycode(260)
			case "AUDIOPLAY": return ParsecKeycode(261)
			case "AUDIOMUTE": return ParsecKeycode(262)
			case "MEDIASELECT": return ParsecKeycode(263)

			default: return nil
		}
	}

	static func getParsecKeycode(for key: String) -> (ParsecKeycode: Int, keyMod: Bool) {
		var keyMod = false
		var parsecKeycode: Int = 0

		switch key {
			// Non-shifted characters
		case "-", "－":  // U+FF0D fullwidth hyphen-minus
			parsecKeycode = 45
		case "=", "＝":  // U+FF1D fullwidth equals sign
			parsecKeycode = 46
		case "[", "［":  // U+FF3B fullwidth left square bracket
			parsecKeycode = 47
		case "]", "］":  // U+FF3D fullwidth right square bracket
			parsecKeycode = 48
		case "\\", "＼":  // U+FF3C fullwidth reverse solidus
			parsecKeycode = 49
		case ";", "；":  // U+FF1B fullwidth semicolon
			parsecKeycode = 51
		case "'", "＇":
			parsecKeycode = 52
		case "`", "｀":
			parsecKeycode = 53
		case ",", "，":  // U+FF0C fullwidth comma
			parsecKeycode = 54
		case ".", "．":  // U+FF0E fullwidth full stop
			parsecKeycode = 55
		case "/", "／":  // U+FF0F fullwidth solidus
			parsecKeycode = 56

			// Shifted characters
		case "_", "＿":  // U+FF3F fullwidth low line
			parsecKeycode = 45
			keyMod = true
		case "+", "＋":  // U+FF0B fullwidth plus sign
			parsecKeycode = 46
			keyMod = true
		case "{", "｛":  // U+FF5B fullwidth left curly bracket
			parsecKeycode = 47
			keyMod = true
		case "}", "｝":  // U+FF5D fullwidth right curly bracket
			parsecKeycode = 48
			keyMod = true
		case "|", "｜":  // U+FF5C fullwidth vertical line
			parsecKeycode = 49
			keyMod = true
		case ":", "：":  // U+FF1A fullwidth colon
			parsecKeycode = 51
			keyMod = true
		case "\"", "＂":
			parsecKeycode = 52
			keyMod = true
		case "~", "～":  // U+FF5E fullwidth tilde
			parsecKeycode = 53
			keyMod = true
		case "<", "＜":  // U+FF1C fullwidth less-than sign
			parsecKeycode = 54
			keyMod = true
		case ">", "＞":  // U+FF1E fullwidth greater-than sign
			parsecKeycode = 55
			keyMod = true
		case "?", "？":  // U+FF1F fullwidth question mark
			parsecKeycode = 56
			keyMod = true
		case "!", "！":  // U+FF01 fullwidth exclamation mark
			parsecKeycode = 30
			keyMod = true
		case "@", "＠":  // U+FF20 fullwidth commercial at
			parsecKeycode = 31
			keyMod = true
		case "#", "＃":  // U+FF03 fullwidth number sign
			parsecKeycode = 32
			keyMod = true
		case "$", "＄":  // U+FF04 fullwidth dollar sign
			parsecKeycode = 33
			keyMod = true
		case "%", "％":  // U+FF05 fullwidth percent sign
			parsecKeycode = 34
			keyMod = true
		case "^", "＾":  // U+FF3E fullwidth circumflex accent
			parsecKeycode = 35
			keyMod = true
		case "&", "＆":  // U+FF06 fullwidth ampersand
			parsecKeycode = 36
			keyMod = true
		case "*", "＊":  // U+FF0A fullwidth asterisk
			parsecKeycode = 37
			keyMod = true
		case "(", "（":  // U+FF08 fullwidth left parenthesis
			parsecKeycode = 38
			keyMod = true
		case ")", "）":  // U+FF09 fullwidth right parenthesis
			parsecKeycode = 39
			keyMod = true

		default:
			parsecKeycode = -1 // Unknown key
		}

		return (parsecKeycode, keyMod)
	}

}
