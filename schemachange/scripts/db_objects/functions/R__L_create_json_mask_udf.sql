CREATE OR REPLACE FUNCTION {{in_sf_env}}_GOVERNANCE_DB.COMPLIANCE.JSON_MASK_FUNC(v variant)
RETURNS variant
LANGUAGE JAVASCRIPT
AS $$

  function process_string(str) {
    const numAstrix = str.length

    return "*".repeat(numAstrix)
  }

  function mask_value(input) {
    if (typeof input === "string") {
      return process_string(input);
    }
    else if (typeof input === "number") {
      return input < 0 ? -1 : input > 0 ? 1 : 0;
    }
    else if (typeof input === "boolean") {
      return null
    }
    return input;
  }

  function traverse_and_mask(input) {
    var masked;
    if (typeof input === "object") {
      masked = {};
      for (var key in input) {
        masked[key] = traverse_and_mask(input[key]);
      }
    }
    else if (Array.isArray(input)) {
       masked = input.map(traverse_and_mask)
    }
    else {
      masked = mask_value(input);
    }
    return masked;
  }

  return traverse_and_mask(V);
$$;