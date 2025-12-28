# ClipboardUtils (`cbu`)

**ClipboardUtils** (`cbu`) is a command-line tool for reading text data from your system clipboard, performing a sequence of operations on that data, and optionally writing the result back to the clipboard or printing it to the console.

This utility is designed to streamline clipboard-based workflows, allowing you to quickly transform, format, or analyze clipboard content using simple commands.

---

## Features

- Read text data directly from the clipboard.
- Chain multiple operations (filters, formatters, converters, etc.) in a single command.
- Output the result to the clipboard, print to the console, or both.
- Easily scriptable and composable for automation.

---

## Installation

This project is developed with zig master (`0.16.0-dev.1484+d0ba6642b`). Clone this repository and follow the build instructions for your platform.

```sh
git clone https://github.com/eltneg/clipboardutils.git
cd clipboardutils
zig build
./zig-out/bin/cbu .print #print your clipboard content to the console
```

---

## Usage

The basic usage pattern is:

```sh
cbu [operation1] [arg1] [operation2] ... [operationN] [argN]
```

### Example

Convert clipboard content to hexadecimal and print the result:

```sh
cbu .tohex .print
```

- `.tohex` — Converts the clipboard text to its hexadecimal representation.
- `.print` — Prints the result to the console.

---

## Common Operations

| Operation      | Description                                                        | Arguments (config)         | Example Usage                                 |
|----------------|--------------------------------------------------------------------|----------------------------|-----------------------------------------------|
| `.noop`        | No operation; does nothing.                                        | None                       | `cbu .noop`                                   |
| `.print`       | Prints the current result to the console.                          | None                       | `cbu .print`                                  |
| `.lowercase`   | Converts text to lowercase.                                        | None                       | `cbu .lowercase .print`                       |
| `.uppercase`   | Converts text to uppercase.                                        | None                       | `cbu .uppercase .print`                       |
| `.len`         | Prints the length of the text.                                     | None                       | `cbu .len`                                    |
| `.reverse`     | Reverses the text.                                                 | None                       | `cbu .reverse .print`                         |
| `.compact`     | Removes whitespace and newlines (outside quotes) from the text.    | None                       | `cbu .compact .print`                         |
| `.fromunix`    | Converts a Unix timestamp (seconds) to a formatted date string.    | None                       | `cbu .fromunix .print`                        |
| `.unixts`      | Gets the current Unix timestamp.                                   | None                       | `cbu .unixts .print`                          |
| `.tob64`       | Encodes text as base64.                                            | None                       | `cbu .tob64 .print`                           |
| `.fromb64`     | Decodes base64 text.                                               | None                       | `cbu .fromb64 .print`                         |
| `.tohex`       | Converts text to hexadecimal representation.                       | None                       | `cbu .tohex .print`                           |
| `.fromhex`     | Converts hexadecimal text back to bytes.                           | None                       | `cbu .fromhex .print`                         |
| `.numtohex`    | Converts a decimal number (as text) to hexadecimal.                | None                       | `cbu .numtohex .print`                        |
| `.numfromhex`  | Converts a hexadecimal number (as text) to decimal.                | None                       | `cbu .numfromhex .print`                      |
| `.tob58`       | Encodes text as base58 (Bitcoin alphabet). (Demo/partial)          | None                       | `cbu .tob58 .print`                           |
| `.fromb58`     | Decodes base58 text. (Demo/partial)                                | None                       | `cbu .fromb58 .print`                         |
| `.arr`         | Parses and formats arrays from text with custom config.             | See below                  | `cbu .arr 'iput=_s,oput=(x.' .print`          |
| `.view`        | Masks parts of the text, showing only specified sections.           | Mask config string         | `cbu .view '3---3' .print`                    |

**Notes:**
- For `.arr`, the config string can specify input/output format, separators, and brackets. Example: `'iput=_s,oput=(x.'`
- For `.view`, the config string specifies how many characters to show at the start/end, e.g., `'3---3'` shows 3 at start and end, masking the rest.

You can chain operations as needed:

```sh
cbu .lowercase .reverse .print
```
This will convert the clipboard text to lowercase, reverse it, and print the result to the console.

## Contributing

Contributions are welcome! Please open issues or submit pull requests for new features, bug fixes, or documentation improvements.

---

## License

This project is licensed under the MIT License.

---

## Author

Developed by [@eltneg](https://github.com/eltneg).

---
