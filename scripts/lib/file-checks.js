// Encoding checks for a transition file, shared by scripts/lint-transitions.js (CI)
// and scripts/preview/validate-transition.js (PR preview comment).

const decoder = new TextDecoder("utf-8", { fatal: true });

// Returns a list of error messages for the raw bytes of a .glsl file.
function checkEncoding(bytes) {
  const errors = [];
  if (bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
    errors.push("remove the UTF-8 byte order mark");
  }
  try {
    decoder.decode(bytes);
  } catch {
    errors.push("must be UTF-8 encoded");
  }
  if (bytes.includes(0x0d)) {
    errors.push("carriage return characters found: use LF (Unix) line endings");
  }
  return errors;
}

module.exports = { checkEncoding };
