# aggregated-clock.el

An Emacs package that aggregates `org-clock` entries from multiple daily timelog files into a single master file. It does so while preserving heading hierarchy and grouping activities by their full outline path.

## Overview

If you keep time logs in separate daily or weekly org files, `aggregated-clock` scans all of them and produces a unified file where clock entries are merged under their original heading structure. This makes it easy to run clock reports or review time spent across a project without manually combining files.

## Requirements

- Emacs with `org-mode` and `org-clock`

## Installation

Clone or download `aggregated-clock.el` and add it to your load path:

```elisp
(add-to-list 'load-path "/path/to/aggregated-clock/")
(require 'aggregated-clock)
```

Or with `use-package`:

```elisp
(use-package aggregated-clock
  :load-path "/path/to/aggregated-clock/")
```

## Configuration

All options are available via `M-x customize-group RET aggregated-clock RET`, or set them directly in your config:

```elisp
;; Directory containing your daily org timelog files (default: ~/org/timelogs/)
(setq aggregated-clock-source-directory "~/org/timelogs/")

;; Output filename, relative to the source directory (default: aggregated_clocks.org)
(setq aggregated-clock-output-file "aggregated_clocks.org")

;; Filename patterns to exclude from processing
;; (default: excludes the output file itself and any clocktable files)
(setq aggregated-clock-exclude-patterns '("aggregated_clocks" "clocktable"))
```

## Usage

Run the aggregation interactively:

```
M-x aggregated-clock-aggregate
```

This will:

1. Recursively scan all `.org` files in `aggregated-clock-source-directory`, skipping any files matching `aggregated-clock-exclude-patterns`.
2. Extract every `LOGBOOK` drawer that contains `CLOCK:` entries.
3. Group entries by their full outline path (e.g. `Project/Task/Subtask`).
4. Write a nested heading structure with all clock entries to the output file.

A message in the minibuffer will confirm the output path and the number of distinct activities found.

## Notes

- Headings at the same path across multiple source files are merged into a single entry in the output.
- The output file is overwritten on each run; it is not intended to be edited manually.
- The output file itself (and any files matching `aggregated-clock-exclude-patterns`) is automatically excluded from processing to prevent circular aggregation.
- If there are any auto-save-files are in the folder then the aggregation will fail.

## Licence

This project is licensed under the GNU General Public License v3.0.
