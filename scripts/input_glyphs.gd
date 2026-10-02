extends RefCounted
# Controls by device (docs/futuro/14 §6, docs/futuro/22): every help text that names a control asks
# here instead of writing the key, so it shows the gamepad button when the player is using a pad.
# The interface follows the last device used (main.gd::_input() calls note()): any gamepad event
# switches to the pad, any key, mouse or touch event back to the keyboard. The pad family (Xbox,
# PlayStation, Nintendo) comes from Input.get_joy_name().
static var device = "teclado"           # "teclado" or "mando"
static var family = "xbox"              # "xbox", "ps" or "nintendo"

# Control → [keyboard and mouse, Xbox, PlayStation, Nintendo]. Xbox names are the generic ones.
# Keys are marked ⟦…⟧ (drawn as a keycap) and pad buttons ⦅…⦆ (drawn round) by
# scripts/glyph_label.gd; plain labels get them without the marks (plain()).
const CONTROLS = {
	"mirar": ["Ratón · ⟦←⟧⟦→⟧⟦↑⟧⟦↓⟧","Stick izquierdo","Stick izquierdo","Stick izquierdo"],
	"zoom": ["Rueda · ⟦W⟧⟦S⟧","Stick derecho ↕","Stick derecho ↕","Stick derecho ↕"],
	"enfoque_mf": ["Rueda · ⟦R⟧⟦T⟧","Stick derecho ↔","Stick derecho ↔","Stick derecho ↔"],
	"enfoque_mf_zoom": ["⟦Mayús⟧+rueda · ⟦R⟧⟦T⟧","Stick derecho ↔","Stick derecho ↔","Stick derecho ↔"],
	"af": ["Clic · ⟦F⟧","⦅A⦆","⦅✕⦆","⦅B⦆"],
	"disparar": ["⟦Espacio⟧","⦅RT⦆","⦅R2⦆","⦅ZR⦆"],
	"diafragma": ["⟦Q⟧⟦E⟧","Cruceta","Cruceta","Cruceta"],
	"velocidad": ["⟦Z⟧⟦X⟧","Cruceta","Cruceta","Cruceta"],
	"iso": ["⟦C⟧⟦V⟧","Cruceta","Cruceta","Cruceta"],
	"compensacion": ["⟦[⟧⟦]⟧","Cruceta","Cruceta","Cruceta"],
	"parametro": ["⟦Q⟧⟦E⟧ · ⟦Z⟧⟦X⟧ · ⟦C⟧⟦V⟧","Cruceta ←→ elige · ↑↓ cambia","Cruceta ←→ elige · ↑↓ cambia","Cruceta ←→ elige · ↑↓ cambia"],
	"punto_enfoque": ["⟦1⟧–⟦9⟧ · clic","⦅LB⦆ ⦅RB⦆","⦅L1⦆ ⦅R1⦆","⦅L⦆ ⦅R⦆"],
	"tercios": ["⟦G⟧","⦅R3⦆","⦅R3⦆","⦅R3⦆"],
	"fotometria": ["⟦M⟧","—","—","—"],
	"bloqueo": ["⟦B⟧","—","—","—"],
	"lupa": ["⟦L⟧","⦅LT⦆","⦅L2⦆","⦅ZL⦆"],
	"manivela": ["⟦K⟧","⦅A⦆","⦅✕⦆","⦅B⦆"],
	"bajar": ["⟦Y⟧","⦅Y⦆","⦅△⦆","⦅X⦆"],
	"ayuda_pantalla": ["⟦F1⟧","⦅X⦆","⦅▢⦆","⦅Y⦆"],
	"controles": ["⟦Tab⟧","⦅View⦆","⦅Share⦆","⦅−⦆"],
	"ayuda": ["⟦H⟧","⦅B⦆","⦅◯⦆","⦅A⦆"],
	"pausa": ["⟦Esc⟧","⦅Menu⦆","⦅Options⦆","⦅+⦆"],
	"atras": ["⟦Esc⟧","⦅B⦆","⦅◯⦆","⦅A⦆"],
	"aceptar": ["⟦Intro⟧","⦅A⦆","⦅✕⦆","⦅B⦆"],
	"cambiar_modo": ["⟦←⟧⟦→⟧","Cruceta ←→ · ⦅LB⦆ ⦅RB⦆","Cruceta ←→ · ⦅L1⦆ ⦅R1⦆","Cruceta ←→ · ⦅L⦆ ⦅R⦆"],
	"andar": ["⟦W⟧⟦A⟧⟦S⟧⟦D⟧","Stick izquierdo","Stick izquierdo","Stick izquierdo"],
	"correr": ["⟦Mayús⟧","⦅L3⦆","⦅L3⦆","⦅L3⦆"],
	"agacharse": ["⟦Ctrl⟧","⦅LT⦆","⦅L2⦆","⦅ZL⦆"],
	"mirar_paseo": ["Ratón","Stick derecho","Stick derecho","Stick derecho"],
	"sacar": ["⟦Y⟧ · clic derecho","⦅Y⦆","⦅△⦆","⦅X⦆"],
}

static func note(event: InputEvent) -> bool:
	var before = device
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > .4):
		device = "mando"
		var joy_name = Input.get_joy_name(event.device).to_lower()
		family = "ps" if ("playstation" in joy_name or "dualshock" in joy_name or "dualsense" in joy_name or "ps4" in joy_name or "ps5" in joy_name) else ("nintendo" if ("nintendo" in joy_name or "switch" in joy_name or "pro controller" in joy_name) else "xbox")
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or (event is InputEventMouseMotion and event.relative.length() > 3.0):
		device = "teclado"
	return device != before

static func pad() -> bool:
	return device == "mando"

# The control's name for the current device, marked (k) or plain (kp).
static func kp(control: String) -> String:
	return plain(k(control))

static func k(control: String) -> String:
	var row: Array = CONTROLS.get(control,[control,control,control,control])
	if device == "teclado": return row[0]
	return row[{"xbox":1,"ps":2,"nintendo":3}[family]]

# Without the keycap and round-button marks, for plain labels and buttons.
static func plain(text: String) -> String:
	return text.replace("⟦","").replace("⟧"," ").replace("⦅","").replace("⦆","").replace("  "," ").strip_edges() if ("⟦" in text or "⦅" in text) else text

# A help text with {control} placeholders, filled in for the current device (with the marks).
static func fill(text: String) -> String:
	var out = text
	for control in CONTROLS:
		var tag = "{"+control+"}"
		if tag in out: out = out.replace(tag,k(control))
	return out
