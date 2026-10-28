extends RefCounted
# Controls by device (docs/futuro/14 §6, docs/futuro/22): every help text that names a control asks
# here instead of writing the key, so it shows the gamepad button when the player is using a pad.
# The interface follows the last device used (main.gd::_input() calls note()): any gamepad event
# switches to the pad, any key, mouse or touch event back to the keyboard. The pad family (Xbox,
# PlayStation, Nintendo) comes from Input.get_joy_name().
static var device = "teclado"           # "teclado", "mando" or "tactil"
# Touch interface on (phones and tablets, or -- --touch): the finger is the device unless a gamepad
# is picked up; keyboard and mouse never take over.
static var touch = false
static var family = "xbox"              # "xbox", "ps" or "nintendo"
const Texts = preload("res://scripts/texts.gd")

# Control → [keyboard and mouse, Xbox, PlayStation, Nintendo]. Xbox names are the generic ones.
# Keys are marked ⟦…⟧ (drawn as a keycap) and pad buttons ⦅…⦆ (drawn round) by
# scripts/glyph_label.gd; plain labels get them without the marks (plain()).
const CONTROLS = {
	"mirar": ["Ratón · ⟦←⟧⟦→⟧⟦↑⟧⟦↓⟧","Stick izquierdo","Stick izquierdo","Stick izquierdo"],
	"girar": ["⟦←⟧⟦→⟧ o ⟦A⟧⟦D⟧","el stick izquierdo","el stick izquierdo","el stick izquierdo"],
	"zoom": ["Rueda · ⟦W⟧⟦S⟧","Stick derecho ↕","Stick derecho ↕","Stick derecho ↕"],
	"enfoque_mf": ["Rueda · ⟦R⟧⟦T⟧","Stick derecho ↔","Stick derecho ↔","Stick derecho ↔"],
	"enfoque_mf_zoom": ["⟦Mayús⟧+rueda · ⟦R⟧⟦T⟧","Stick derecho ↔","Stick derecho ↔","Stick derecho ↔"],
	"af": ["Clic · ⟦F⟧","⦅RT⦆ a medias","⦅R2⦆ a medias","⦅ZR⦆ a medias"],
	"disparar": ["⟦Espacio⟧","⦅RT⦆","⦅R2⦆","⦅ZR⦆"],
	"diafragma": ["⟦Q⟧⟦E⟧","Cruceta","Cruceta","Cruceta"],
	"velocidad": ["⟦Z⟧⟦X⟧","Cruceta","Cruceta","Cruceta"],
	"iso": ["⟦C⟧⟦V⟧","Cruceta","Cruceta","Cruceta"],
	"compensacion": ["⟦[⟧⟦]⟧","Cruceta","Cruceta","Cruceta"],
	"diafragma_y": ["⟦Q⟧ y ⟦E⟧","la cruceta ↑↓","la cruceta ↑↓","la cruceta ↑↓"],
	"velocidad_y": ["⟦Z⟧ y ⟦X⟧","la cruceta ↑↓","la cruceta ↑↓","la cruceta ↑↓"],
	"iso_y": ["⟦C⟧ y ⟦V⟧","la cruceta ↑↓","la cruceta ↑↓","la cruceta ↑↓"],
	"elegir_tab": ["⟦Tab⟧","la cruceta ←→","la cruceta ←→","la cruceta ←→"],
	"cambiar_pag": ["⟦Re Pág⟧ y ⟦Av Pág⟧","la cruceta ↑↓","la cruceta ↑↓","la cruceta ↑↓"],
	"elegir_control": ["clic · ⟦Tab⟧","Cruceta ←→","Cruceta ←→","Cruceta ←→"],
	"cambiar_control": ["rueda · ⟦Re Pág⟧⟦Av Pág⟧","Cruceta ↑↓","Cruceta ↑↓","Cruceta ↑↓"],
	"parametro": ["⟦Q⟧⟦E⟧ · ⟦Z⟧⟦X⟧ · ⟦C⟧⟦V⟧","Cruceta ←→ elige · ↑↓ cambia","Cruceta ←→ elige · ↑↓ cambia","Cruceta ←→ elige · ↑↓ cambia"],
	"punto_enfoque": ["⟦1⟧–⟦9⟧ · clic","⦅LB⦆ ⦅RB⦆","⦅L1⦆ ⦅R1⦆","⦅L⦆ ⦅R⦆"],
	"tercios": ["⟦G⟧","⦅R3⦆","⦅R3⦆","⦅R3⦆"],
	"fotometria": ["⟦M⟧","—","—","—"],
	"bloqueo": ["⟦B⟧","⦅RT⦆ a medias","⦅R2⦆ a medias","⦅ZR⦆ a medias"],
	"lupa": ["⟦L⟧","⦅LT⦆","⦅L2⦆","⦅ZL⦆"],
	"manivela": ["⟦K⟧","⦅X⦆","⦅▢⦆","⦅Y⦆"],
	"bajar": ["⟦Y⟧","⦅Y⦆","⦅△⦆","⦅X⦆"],
	"paso_entero": ["⟦Mayús⟧ pulsada","la cruceta mantenida","la cruceta mantenida","la cruceta mantenida"],
	"ayuda_pantalla": ["⟦I⟧","⦅X⦆","⦅▢⦆","⦅Y⦆"],
	"controles": ["⟦Tab⟧","⦅View⦆","⦅Share⦆","⦅−⦆"],
	"ayuda": ["⟦H⟧","⦅B⦆","⦅◯⦆","⦅A⦆"],
	"pausa": ["⟦Esc⟧","⦅Menu⦆","⦅Options⦆","⦅+⦆"],
	"atras": ["⟦Esc⟧","⦅B⦆","⦅◯⦆","⦅A⦆"],
	"aceptar": ["⟦Intro⟧","⦅A⦆","⦅✕⦆","⦅B⦆"],
	"elegir_opcion": ["⟦↑⟧⟦↓⟧","Cruceta ↑↓","Cruceta ↑↓","Cruceta ↑↓"],
	"cambiar_modo": ["⟦←⟧⟦→⟧","Cruceta ←→ · ⦅LB⦆ ⦅RB⦆","Cruceta ←→ · ⦅L1⦆ ⦅R1⦆","Cruceta ←→ · ⦅L⦆ ⦅R⦆"],
	"andar": ["⟦W⟧⟦A⟧⟦S⟧⟦D⟧","Stick izquierdo","Stick izquierdo","Stick izquierdo"],
	"correr": ["⟦Mayús⟧","⦅L3⦆","⦅L3⦆","⦅L3⦆"],
	"agacharse": ["⟦Ctrl⟧","⦅LT⦆","⦅L2⦆","⦅ZL⦆"],
	"mirar_paseo": ["Ratón","Stick derecho","Stick derecho","Stick derecho"],
	"sacar": ["⟦Y⟧ · clic derecho","⦅Y⦆","⦅△⦆","⦅X⦆"],
}

# The same controls with the fingers (scripts/touch_controls.gd).
const TOUCH = {
	"mirar": "arrastrando un dedo por la imagen", "girar": "el dedo sobre la imagen", "zoom": "pellizcando con dos dedos", "enfoque_mf": "Enfoque en la tira y − +",
	"enfoque_mf_zoom": "Enfoque en la tira y − +", "af": "un toque sobre ella o «AF»", "disparar": "●",
	"diafragma": "tócalo en la tira y usa − +", "velocidad": "tócala en la tira y usa − +", "iso": "tócalo en la tira y usa − +",
	"compensacion": "tócala en la tira y usa − +", "diafragma_y": "− y +, tras tocarlo en la tira", "velocidad_y": "− y +, tras tocarla en la tira",
	"iso_y": "− y +, tras tocarlo en la tira", "elegir_tab": "un toque en la tira", "cambiar_pag": "− y +",
	"elegir_control": "un toque en la tira", "cambiar_control": "− y +", "parametro": "la tira de abajo y − +",
	"punto_enfoque": "un toque en la imagen", "tercios": "«Tercios»", "fotometria": "el botón de medición", "bloqueo": "«Bloqueo»",
	"lupa": "«Lupa»", "manivela": "«Manivela»", "bajar": "«Cámara»", "ayuda_pantalla": "—", "paso_entero": "− o + mantenidos", "controles": "la tira",
	"ayuda": "«Ayuda»", "pausa": "«Pausa»", "atras": "«Atrás»", "aceptar": "un toque", "elegir_opcion": "un toque",
	"cambiar_modo": "‹ › o deslizando", "andar": "la palanca de la izquierda", "correr": "«Correr»",
	"agacharse": "«Agacharse»", "mirar_paseo": "arrastrando un dedo", "sacar": "«Cámara»",
}

# The same in English (scripts/texts.gd decides the language). Every control of CONTROLS and TOUCH
# must be here too (tests/test_texts.gd).
const CONTROLS_EN = {
	"mirar": ["Mouse · ⟦←⟧⟦→⟧⟦↑⟧⟦↓⟧","Left stick","Left stick","Left stick"],
	"girar": ["⟦←⟧⟦→⟧ or ⟦A⟧⟦D⟧","the left stick","the left stick","the left stick"],
	"zoom": ["Wheel · ⟦W⟧⟦S⟧","Right stick ↕","Right stick ↕","Right stick ↕"],
	"enfoque_mf": ["Wheel · ⟦R⟧⟦T⟧","Right stick ↔","Right stick ↔","Right stick ↔"],
	"enfoque_mf_zoom": ["⟦Shift⟧+wheel · ⟦R⟧⟦T⟧","Right stick ↔","Right stick ↔","Right stick ↔"],
	"af": ["Click · ⟦F⟧","⦅RT⦆ half-press","⦅R2⦆ half-press","⦅ZR⦆ half-press"],
	"disparar": ["⟦Space⟧","⦅RT⦆","⦅R2⦆","⦅ZR⦆"],
	"diafragma": ["⟦Q⟧⟦E⟧","D-pad","D-pad","D-pad"],
	"velocidad": ["⟦Z⟧⟦X⟧","D-pad","D-pad","D-pad"],
	"iso": ["⟦C⟧⟦V⟧","D-pad","D-pad","D-pad"],
	"compensacion": ["⟦[⟧⟦]⟧","D-pad","D-pad","D-pad"],
	"diafragma_y": ["⟦Q⟧ and ⟦E⟧","the D-pad ↑↓","the D-pad ↑↓","the D-pad ↑↓"],
	"velocidad_y": ["⟦Z⟧ and ⟦X⟧","the D-pad ↑↓","the D-pad ↑↓","the D-pad ↑↓"],
	"iso_y": ["⟦C⟧ and ⟦V⟧","the D-pad ↑↓","the D-pad ↑↓","the D-pad ↑↓"],
	"elegir_tab": ["⟦Tab⟧","the D-pad ←→","the D-pad ←→","the D-pad ←→"],
	"cambiar_pag": ["⟦PgUp⟧ and ⟦PgDn⟧","the D-pad ↑↓","the D-pad ↑↓","the D-pad ↑↓"],
	"elegir_control": ["click · ⟦Tab⟧","D-pad ←→","D-pad ←→","D-pad ←→"],
	"cambiar_control": ["wheel · ⟦PgUp⟧⟦PgDn⟧","D-pad ↑↓","D-pad ↑↓","D-pad ↑↓"],
	"parametro": ["⟦Q⟧⟦E⟧ · ⟦Z⟧⟦X⟧ · ⟦C⟧⟦V⟧","D-pad ←→ picks · ↑↓ changes","D-pad ←→ picks · ↑↓ changes","D-pad ←→ picks · ↑↓ changes"],
	"punto_enfoque": ["⟦1⟧–⟦9⟧ · click","⦅LB⦆ ⦅RB⦆","⦅L1⦆ ⦅R1⦆","⦅L⦆ ⦅R⦆"],
	"tercios": ["⟦G⟧","⦅R3⦆","⦅R3⦆","⦅R3⦆"],
	"fotometria": ["⟦M⟧","—","—","—"],
	"bloqueo": ["⟦B⟧","⦅RT⦆ half-press","⦅R2⦆ half-press","⦅ZR⦆ half-press"],
	"lupa": ["⟦L⟧","⦅LT⦆","⦅L2⦆","⦅ZL⦆"],
	"manivela": ["⟦K⟧","⦅X⦆","⦅▢⦆","⦅Y⦆"],
	"bajar": ["⟦Y⟧","⦅Y⦆","⦅△⦆","⦅X⦆"],
	"paso_entero": ["⟦Shift⟧ held","the D-pad held","the D-pad held","the D-pad held"],
	"ayuda_pantalla": ["⟦I⟧","⦅X⦆","⦅▢⦆","⦅Y⦆"],
	"controles": ["⟦Tab⟧","⦅View⦆","⦅Share⦆","⦅−⦆"],
	"ayuda": ["⟦H⟧","⦅B⦆","⦅◯⦆","⦅A⦆"],
	"pausa": ["⟦Esc⟧","⦅Menu⦆","⦅Options⦆","⦅+⦆"],
	"atras": ["⟦Esc⟧","⦅B⦆","⦅◯⦆","⦅A⦆"],
	"aceptar": ["⟦Enter⟧","⦅A⦆","⦅✕⦆","⦅B⦆"],
	"elegir_opcion": ["⟦↑⟧⟦↓⟧","D-pad ↑↓","D-pad ↑↓","D-pad ↑↓"],
	"cambiar_modo": ["⟦←⟧⟦→⟧","D-pad ←→ · ⦅LB⦆ ⦅RB⦆","D-pad ←→ · ⦅L1⦆ ⦅R1⦆","D-pad ←→ · ⦅L⦆ ⦅R⦆"],
	"andar": ["⟦W⟧⟦A⟧⟦S⟧⟦D⟧","Left stick","Left stick","Left stick"],
	"correr": ["⟦Shift⟧","⦅L3⦆","⦅L3⦆","⦅L3⦆"],
	"agacharse": ["⟦Ctrl⟧","⦅LT⦆","⦅L2⦆","⦅ZL⦆"],
	"mirar_paseo": ["Mouse","Right stick","Right stick","Right stick"],
	"sacar": ["⟦Y⟧ · right-click","⦅Y⦆","⦅△⦆","⦅X⦆"],
}

const TOUCH_EN = {
	"mirar": "dragging a finger across the picture", "girar": "your finger on the picture", "zoom": "pinching with two fingers", "enfoque_mf": "Focus on the strip and − +",
	"enfoque_mf_zoom": "Focus on the strip and − +", "af": "a tap on them or “AF”", "disparar": "●",
	"diafragma": "tap it on the strip and use − +", "velocidad": "tap it on the strip and use − +", "iso": "tap it on the strip and use − +",
	"compensacion": "tap it on the strip and use − +", "diafragma_y": "− and +, after tapping it on the strip", "velocidad_y": "− and +, after tapping it on the strip",
	"iso_y": "− and +, after tapping it on the strip", "elegir_tab": "a tap on the strip", "cambiar_pag": "− and +",
	"elegir_control": "a tap on the strip", "cambiar_control": "− and +", "parametro": "the strip below and − +",
	"punto_enfoque": "a tap on the picture", "tercios": "“Thirds”", "fotometria": "the metering button", "bloqueo": "“Lock”",
	"lupa": "“Loupe”", "manivela": "“Crank”", "bajar": "“Camera”", "ayuda_pantalla": "—", "paso_entero": "− or + held", "controles": "the strip",
	"ayuda": "“Help”", "pausa": "“Pause”", "atras": "“Back”", "aceptar": "a tap", "elegir_opcion": "a tap",
	"cambiar_modo": "‹ › or swiping", "andar": "the stick on the left", "correr": "“Run”",
	"agacharse": "“Crouch”", "mirar_paseo": "dragging a finger", "sacar": "“Camera”",
}

const MOUSE_SWITCH = 60.0        # pixels the mouse must travel within 0.4 s to take over
static var mouse_travel = 0.0
static var mouse_since = 0
static func note(event: InputEvent) -> bool:
	var before = device
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > .4):
		device = "mando"
		var joy_name = Input.get_joy_name(event.device).to_lower()
		family = "ps" if ("playstation" in joy_name or "dualshock" in joy_name or "dualsense" in joy_name or "ps4" in joy_name or "ps5" in joy_name) else ("nintendo" if ("nintendo" in joy_name or "switch" in joy_name or "pro controller" in joy_name) else "xbox")
	elif touch:
		if event is InputEventScreenTouch or event is InputEventMouseButton: device = "tactil"
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		device = "teclado"
	elif event is InputEventMouseMotion:
		# Only a real move of the mouse: a few pixels of drift (the mouse nudged on the desk, the
		# sensor's own jitter) switched the help back to the keys while playing with the gamepad.
		var now = Time.get_ticks_msec()
		if now-mouse_since > 400:
			mouse_since = now
			mouse_travel = 0.0
		mouse_travel += event.relative.length()
		if mouse_travel > MOUSE_SWITCH: device = "teclado"
	return device != before

static func pad() -> bool:
	return device == "mando"

# The control's name for the current device, marked (k) or plain (kp).
static func kp(control: String) -> String:
	return plain(k(control))

static func k(control: String) -> String:
	var english = Texts.current() == "en"
	var row: Array = (CONTROLS_EN if english else CONTROLS).get(control,[control,control,control,control])
	if device == "tactil": return (TOUCH_EN if english else TOUCH).get(control,row[0])
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
