## Technical Maintenance Documentation: Local Offline HL7 v2 Parser
This document provides a comprehensive technical overview and maintenance guide for hl7_local_parser.html, a single-file, client-side web application designed to break down and filter HL7 v2 medical telemetry data without transferring data to an external server.
------------------------------
## 🛠️ Architecture Overview
The application is structured entirely as a monolithic single-file app (HTML5/CSS3/Vanilla JavaScript ES6). It requires no backend server, node modules, build pipelines, or third-party CDN dependencies.

┌────────────────────────────────────────────────────────┐
│               hl7_local_parser.html                    │
├───────────────────┬───────────────────┬────────────────┤
│    UI Layer       │  Filtering Engine │ Parsing Engine │
│ (HTML5/CSS Grid)  │ (Regex / Sets)    │ (Data State)   │
└───────────────────┴───────────────────┴────────────────┘

## Key Technical Attributes

* Zero Data Footprint: Data privacy is handled completely in-browser via local client execution loops.
* Responsive CSS Grid Layout: Uses a modern CSS variables framework alongside an adaptive media query grid breakdown (1fr on mobile, 1fr 1fr split-pane on desktop configurations >= 768px).

------------------------------
## 📊 Core Data Architecture## Global Data State
The application tracks state using two core global objects:

let activeQuickFilters = new Set();     // Track active high-priority field tagslet parsedSegmentsGlobal = [];          // Master array holding full parsed payload schema

## Parsed Segment Schema (parsedSegmentsGlobal)
When an HL7 payload string gets mapped, each valid entry is injected into the master array following this explicit structure:

{
  index: Number,       // Original line array position index
  name: String,        // Three-character segment identity string (e.g., 'MSH', 'PID')
  raw: String,         // Unaltered source payload string for the row
  fs: String,          // Active dynamic field separator delimiter parsed out 
  fields: [            // Sub-array breakdown mapping individual data segments
    {
      num: Number,     // Sequential field location marker index
      key: String,     // Absolute reference compound string key (e.g., 'PID.3')
      name: String,    // Dictionary-mapped clear name descriptor
      value: String    // Raw target payload text block
    }
  ]
}

------------------------------
## ⚙️ Function Breakdown & Logic## 1. Core Parsing Loop: parseHL7()
Purpose: Normalizes incoming streams, isolates segments, shifts indices dynamically for header elements, and maps structural data models.

* Line Normalization: Splits incoming data strings using the regex /[\r\n]+/ to clean mixed carriage returns and newline breaks uniformly.
* MSH Index Shift Mitigation: HL7 MSH segments treat the first delimiter symbol as a dedicated data field (MSH.1). To avoid indexing off-by-one mismatches against downstream components, the code uses a selective array splice payload mutation:

if (segName === 'MSH') {
    fs = line.charAt(3) || '|';
    fields = line.split(fs);
    fields.splice(1, 0, fs); // Forces structural compliance alignment
}

* Dynamic Delimiter Extraction: Pulls out the field separator directly from character position 3 of the MSH block. Non-MSH fields lookup and inherit whatever active token (fs) was captured during processing of the initial header segment block.

## 2. State & UI Filtering: applyFilters()
Purpose: Evaluates strict logical intersections across multi-tier criteria sets and handles DOM generation patterns dynamically.

* Intersection Logic Rule: A segment is rendered only if it passes three distinct evaluations simultaneously:
$$\text{Visible} = (\text{Segment Dropdown Match}) \land (\text{Search Query Match}) \land (\text{Active QuickFilter Tag Match})$$ 
* Search Traversal Execution: Matches the free-text input search parameter against the entire unparsed segment line raw text footprint using .includes() string evaluations.
* QuickFilter Array Scanning: Evaluates multi-set filters using .some() loops to determine whether at least one non-empty string payload directly fulfills active tracking sets.

## 3. Dynamic Tag Toggling: toggleQuickFilter(fieldKey, element)
Purpose: Modifies native state indicators mapping specific HL7 fields.

* Uses native JavaScript Set.prototype.has(), .add(), and .delete() methods to maintain constant time (O(1)) evaluations across selected search variations.

------------------------------
## 🛠️ Maintenance & Extensibility Workflows## How to Add a New Segment Definition
To support additional field translation names beyond the default dictionary (MSH, PID, PV1, SCH), locate the global dictionary constant and register the new target mapping pairs:

const dictionary = {
    // Existing fields...
    'SCH.20': 'Entered By Person',
    
    // Custom Maintenance Additions:
    'OBX.1': 'Set ID - OBX',
    'OBX.2': 'Value Type',
    'OBX.3': 'Observation Identifier'
};

## How to Add a Specialized Target Quick Filter Button
To expose new button tags in the interface layer, edit the HTML inside the .quick-filters container block:

<!-- Example: Adding an OBX filter tag to the template layout -->
<span class="tag" onclick="toggleQuickFilter('OBX.3', this)">OBX.3 (Observation Identifier)</span>

------------------------------
## ⚠️ Potential Issues & Edge Cases

   1. Missing Component / Sub-component Separation Logic: This tool splits data strictly at the field level (|). It does not parse sub-components separated by carets (^) or ampersands (&). Sub-component strings are rendered together inside the raw field block value.
   2. Missing Out-of-Order MSH Segments Handling: The dynamic delimiter parsing mechanism assumes that an MSH segment will be processed first in the payload sequence. Pasting segmented payload fragments missing an explicit leading MSH line defaults structural layouts strictly to pipe (|) boundaries.
   3. No Structural Validation: The tool behaves purely as a visual mapping parser. It does not enforce data types, check required fields, or validate lengths against standard HL7 specifications.

