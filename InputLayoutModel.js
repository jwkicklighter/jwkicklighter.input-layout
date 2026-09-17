var UNTYPED_KEYBOARDS = /^(hl-virtual-keyboard|power-button|sleep-button|lid-switch|video-bus)/

var VARIANT_LABELS = {
  "dvorak": "DV",
  "dvorak-l": "DVL",
  "dvorak-r": "DVR",
  "dvorak-classic": "DVC",
  "dvorak-alt-intl": "DAI",
  "dvp": "DVP",
  "colemak": "CM",
  "colemak_dh": "CDH",
  "colemak_dh_wide": "CDW",
  "colemak_dh_ortho": "CDO",
  "colemak_dh_iso": "CDI",
  "workman": "WM",
  "workman-intl": "WMI",
  "intl": "INT",
  "alt-intl": "AIN",
  "altgr-intl": "AGI",
  "euro": "EU",
  "mac": "MAC",
  "phonetic": "PH"
}

function isTypedKeyboard(name) {
  return !UNTYPED_KEYBOARDS.test(String(name || ""))
}

function eventKeyboardName(event) {
  var parts

  try {
    if (event && event.parse) parts = event.parse(2)
  } catch (error) {
  }

  if (!parts) parts = String(event && event.data ? event.data : "").split(",")

  var name = String(parts[0] || "")
  return name.indexOf("hl-virtual-keyboard") === 0 ? "" : name
}

function selectKeyboard(typed, namedByEvent) {
  var keyboards = typed || []

  return keyboards.find(function (keyboard) {
    return keyboard.name === namedByEvent
  }) || keyboards.reduce(function (furthest, keyboard) {
    return layoutIndex(keyboard) > layoutIndex(furthest) ? keyboard : furthest
  }, keyboards[0])
}

function layoutIndex(keyboard) {
  return (keyboard && keyboard.active_layout_index) || 0
}

function makeId(layout, variant) {
  layout = String(layout || "")
  variant = String(variant || "")
  if (!layout) return ""
  return variant ? layout + "(" + variant + ")" : layout
}

function splitId(id) {
  var s = String(id || "")
  var open = s.indexOf("(")
  if (open > 0 && s.charAt(s.length - 1) === ")") {
    return {
      layout: s.substring(0, open),
      variant: s.substring(open + 1, s.length - 1)
    }
  }
  return { layout: s, variant: "" }
}

function parseIds(layoutStr, variantStr) {
  var layouts = String(layoutStr || "").split(",")
  var variants = String(variantStr || "").split(",")
  var ids = []
  for (var i = 0; i < layouts.length; i++) {
    var layout = layouts[i]
    if (!layout) continue
    ids.push(makeId(layout, variants[i] || ""))
  }
  return ids
}

function toHyprland(ids) {
  var layouts = []
  var variants = []
  ;(ids || []).forEach(function (id) {
    var parts = splitId(id)
    if (!parts.layout) return
    layouts.push(parts.layout)
    variants.push(parts.variant)
  })
  return {
    layout: layouts.join(","),
    variant: variants.join(",")
  }
}

function variantLabel(variant) {
  variant = String(variant || "")
  if (!variant) return ""
  if (VARIANT_LABELS[variant]) return VARIANT_LABELS[variant]
  return variant.replace(/[^A-Za-z0-9]/g, "").substring(0, 3).toUpperCase()
}

function shortLabel(id, table) {
  if (!id) return ""
  var info = ((table && table.byId) || {})[id]
  var parts = info ? { layout: info.layout, variant: info.variant } : splitId(id)
  if (parts.variant) return variantLabel(parts.variant)
  return String(parts.layout || id).substring(0, 3).toUpperCase()
}

function rowForId(id, table) {
  var info = ((table && table.byId) || {})[id]
  var parts = info ? { layout: info.layout, variant: info.variant } : splitId(id)
  return {
    id: id,
    layout: parts.layout,
    variant: parts.variant,
    label: shortLabel(id, table) || String(id).substring(0, 3).toUpperCase(),
    description: (info && info.description) || id
  }
}

function rowsForLayouts(ids, table) {
  return (ids || []).filter(function (id) {
    return String(id).length > 0
  }).map(function (id) {
    return rowForId(id, table)
  })
}

function layoutTable(text) {
  var byId = {}
  var byDescription = {}
  var current = null

  String(text || "").split("\n").forEach(function (line) {
    var layoutMatch = line.match(/^-\s+layout:\s+'([^']+)'$/)
    if (layoutMatch) {
      current = { layout: layoutMatch[1], variant: null, brief: "", description: "" }
      return
    }
    if (!current) return

    var variantMatch = line.match(/^  variant:\s*'([^']*)'$/)
    if (variantMatch) {
      current.variant = variantMatch[1]
      return
    }

    var briefMatch = line.match(/^  brief:\s*'([^']+)'$/)
    if (briefMatch) {
      current.brief = briefMatch[1]
      return
    }

    var descriptionMatch = line.match(/^  description:\s*(.*)$/)
    if (!descriptionMatch) return

    current.description = descriptionMatch[1].trim().replace(/^'|'$/g, "")
    if (current.variant === null || !current.description) return

    var id = makeId(current.layout, current.variant)
    if (!byId[id]) {
      byId[id] = {
        id: id,
        layout: current.layout,
        variant: current.variant,
        brief: current.brief,
        description: current.description
      }
    }
    if (!byDescription[current.description]) byDescription[current.description] = id
    current = null
  })

  return { byId: byId, byDescription: byDescription }
}

function scoreRow(row, q) {
  var id = String(row.id || "").toLowerCase()
  var layout = String(row.layout || "").toLowerCase()
  var variant = String(row.variant || "").toLowerCase()
  var desc = String(row.description || "").toLowerCase()
  var label = String(row.label || "").toLowerCase()
  var score = 0
  if (id === q) score += 1000
  if (variant === q) score += 400
  if (layout === q) score += 300
  if (label.toLowerCase() === q) score += 250
  if (desc === q) score += 200
  if (variant.indexOf(q) === 0) score += 80
  if (desc.indexOf(q) === 0) score += 60
  if (desc.indexOf(q) !== -1) score += 40
  if (id.indexOf(q) !== -1) score += 20
  if (!variant && q === "qwerty") score += 120
  if (!variant && layout === "us" && q === "qwerty") score += 500
  if (layout === "us") score += 15
  return score
}

function searchCatalog(query, excludeIds, table, limit) {
  var byId = (table && table.byId) || {}
  var q = String(query || "").toLowerCase()
  if (!q) return []
  var exclude = {}
  ;(excludeIds || []).forEach(function (id) {
    exclude[id] = true
  })
  var scored = []
  Object.keys(byId).forEach(function (id) {
    if (exclude[id]) return
    var row = rowForId(id, table)
    var extra = row.variant ? "" : " qwerty"
    var hay = (row.id + " " + row.layout + " " + row.variant + " " + row.label + " " + row.description + extra).toLowerCase()
    if (hay.indexOf(q) === -1) return
    scored.push({ row: row, score: scoreRow(row, q) })
  })
  scored.sort(function (a, b) {
    if (b.score !== a.score) return b.score - a.score
    return String(a.row.description).localeCompare(String(b.row.description))
  })
  return scored.slice(0, limit || 30).map(function (entry) {
    return entry.row
  })
}

function joined(ids) {
  return (ids || []).filter(function (id) {
    return String(id).length > 0
  }).join(",")
}

if (typeof module !== "undefined") {
  module.exports = {
    eventKeyboardName: eventKeyboardName,
    isTypedKeyboard: isTypedKeyboard,
    joined: joined,
    layoutTable: layoutTable,
    makeId: makeId,
    parseIds: parseIds,
    rowForId: rowForId,
    rowsForLayouts: rowsForLayouts,
    searchCatalog: searchCatalog,
    selectKeyboard: selectKeyboard,
    shortLabel: shortLabel,
    splitId: splitId,
    toHyprland: toHyprland,
    variantLabel: variantLabel
  }
}
