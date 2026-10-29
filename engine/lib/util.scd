// Helpers: JSON encoding, files, timestamps, logging.
// Engine functions live in one Event and are called as ps.method(...); each gets the Event as `self`.
(
// keys set at runtime; listed so assertKeys can check them too
dataKeys: #[server, synths, patterns, channels, subscribers, oscDefs, masterBus, inputBus,
	inputGroup, sourceGroup, testGroup, masterGroup, masterSynth, inputSynth, treeFunc, recPath,
	isReady, commands, stateToken, startedAt, watched, watchMtimes, watchRoutine,
	pendingStops],

// Event methods win over keys (e.g. ps.play would call Event:play), so refuse clashing names
assertKeys: { |self|
	var bad = (self.keys.asArray ++ self.dataKeys).select { |k| Event.findRespondingMethodFor(k).notNil };
	if (bad.notEmpty) { Error("[ps] engine keys clash with Event methods: %".format(bad)).throw };
},

log: { |self, str| ("[ps] " ++ str).postln },

// brackets the post window output of an evaluation so the daemon can attach it to a result
logMark: { |self, which, id| "[ps:log-%:%]".format(which, id).postln },

jsonEncode: { |self, obj|
	case
	{ obj.isNil } { "null" }
	{ obj.isKindOf(Boolean) } { obj.asString }
	{ obj.isKindOf(Symbol) } { self.jsonQuote(obj.asString) }
	{ obj.isString } { self.jsonQuote(obj) }
	{ obj.isNumber } { if (obj.isNaN or: { obj.abs == inf }) { "null" } { obj.asString } }
	{ obj.isKindOf(Dictionary) } {
		"{" ++ obj.keys.asArray.sort { |a, b| a.asString < b.asString }.collect { |k|
			self.jsonQuote(k.asString) ++ ":" ++ self.jsonEncode(obj[k])
		}.join(",") ++ "}"
	}
	{ obj.isSequenceableCollection } { "[" ++ obj.asArray.collect { |x| self.jsonEncode(x) }.join(",") ++ "]" }
	{ self.jsonQuote(obj.asString) }
},

jsonQuote: { |self, str|
	var out = CollStream(String.new);
	out << $";
	str.do { |c|
		case
		{ c == $" } { out << "\\\"" }
		{ c == $\\ } { out << "\\\\" }
		{ c == $\n } { out << "\\n" }
		{ c == $\r } { out << "\\r" }
		{ c == $\t } { out << "\\t" }
		{ c.ascii >= 0 and: { c.ascii < 32 } } { out << "\\u" << c.ascii.asHexString(4) }
		{ out << c };
	};
	out << $";
	out.contents
},

readFile: { |self, path|
	if (File.exists(path)) { File.readAllString(path) }
},

writeFile: { |self, path, str|
	File.mkdir(path.dirname);
	File.use(path, "w", { |f| f.write(str) });
},

timestamp: { |self| Date.getDate.format("%Y%m%d-%H%M%S") },
isoNow: { |self| Date.getDate.format("%Y-%m-%dT%H:%M:%S") },

validName: { |self, name|
	var str = name.asString;
	"^[A-Za-z][A-Za-z0-9_]{0,63}$".matchRegexp(str) and: { str.beginsWith("ps_").not }
},

errorText: { |self, err|
	var str;
	if (err.isKindOf(Exception)) {
		str = err.errorString;
		if (str.beginsWith("ERROR: ")) { str = str.drop(7) };
		if (err.isKindOf(DoesNotUnderstandError)) {
			str = str ++ " (receiver: " ++ err.receiver.asString.keep(80) ++ ")"
		};
		str
	} { err.asString }
},

// wait up to `limit` seconds for `test` to become true; call from a Routine
waitFor: { |self, limit, test|
	var t = 0;
	while { test.value.not and: { t < limit } } { 0.05.wait; t = t + 0.05 };
	test.value
}
)
