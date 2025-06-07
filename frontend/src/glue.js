let wasmInstance;
let memory;

const utf8Encoder = new TextEncoder();

let sessionId = "abc123";
let token = "fake-auth-token";
let invitedShown = false;

function allocUTF8(str) {
  const bytes = utf8Encoder.encode(str + "\0"); // null-terminated
  const ptr = wasmInstance.exports.alloc(bytes.length);
  new Uint8Array(memory.buffer, ptr, bytes.length).set(bytes);
  return ptr;
}

const imports = {
  env: {
    js_get_session_id: () => allocUTF8(sessionId),
    js_get_session_id_len: () => sessionId.length,
    js_get_token: () => allocUTF8(token),
    js_get_token_len: () => token.length,
    js_get_invited_shown: () => invitedShown ? 1 : 0,
    js_set_invited_shown: (val) => { invitedShown = !!val; },

    // If you're using raylib-zig or want logging:
    // js_log: (ptr, len) => {
    //   const msg = new TextDecoder("utf-8").decode(
    //     new Uint8Array(memory.buffer, ptr, len)
    //   );
    //   console.log("[zig]", msg);
    // },
  }
};

WebAssembly.instantiateStreaming(fetch("truthbyte.wasm"), imports)
  .then(({ instance }) => {
    wasmInstance = instance;
    memory = instance.exports.memory;
    instance.exports.main(); // or whatever your Zig entrypoint is
  }
);
