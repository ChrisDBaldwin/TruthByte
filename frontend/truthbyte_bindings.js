mergeInto(LibraryManager.library, {
  get_canvas_width: function() {
    var canvas = document.getElementById("canvas");
    return canvas ? canvas.width : window.innerWidth;
  },
  
  get_canvas_height: function() {
    var canvas = document.getElementById("canvas");
    return canvas ? canvas.height : window.innerHeight;
  },
  
  get_session_id: function() {
    // Return a pointer to a dummy string for now
    var sessionId = "demo-session-123";
    var len = lengthBytesUTF8(sessionId) + 1;
    var ptr = _malloc(len);
    stringToUTF8(sessionId, ptr, len);
    return ptr;
  },
  
  get_session_id_len: function() {
    return lengthBytesUTF8("demo-session-123");
  },
  
  get_token: function() {
    var token = "demo-token-456";
    var len = lengthBytesUTF8(token) + 1;
    var ptr = _malloc(len);
    stringToUTF8(token, ptr, len);
    return ptr;
  },
  
  get_token_len: function() {
    return lengthBytesUTF8("demo-token-456");
  },
  
  get_invited_shown: function () {
    return 0;
  },

  set_invited_shown: function(val) {
    console.log("invited shown:", !!val);
  }
});
