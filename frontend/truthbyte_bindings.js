// JWT Authentication variables - declared outside the library object
var _authToken = null;
var _sessionId = null;
var _userId = null;

// Minimal localStorage interface for Zig user module
function js_get_local_storage(key_ptr, key_len, value_ptr, value_len) {
  if (typeof localStorage === 'undefined') return 0;
  
  var key = UTF8ToString(key_ptr, key_len);
  var value = localStorage.getItem(key);
  
  if (!value) return 0;
  
  var bytes_to_copy = Math.min(value.length, value_len - 1); // Leave space for null terminator
  stringToUTF8(value, value_ptr, bytes_to_copy + 1);
  
  return bytes_to_copy;
}

function js_set_local_storage(key_ptr, key_len, value_ptr, value_len) {
  if (typeof localStorage === 'undefined') return;
  
  var key = UTF8ToString(key_ptr, key_len);
  var value = UTF8ToString(value_ptr, value_len);
  
  localStorage.setItem(key, value);
}


// Touch input tracking variables - only set if window exists (browser environment)
if (typeof window !== 'undefined') {
  window._lastInputX = 0;
  window._lastInputY = 0;
  window._inputActive = false;
  window._touchTimeout = null; // Timeout to reset stuck touch state
}

// Touch event listener setup function
function setupTouchListeners() {
  var canvas = document.getElementById('canvas');
  if (canvas && !canvas._touchListenersAdded) {
    canvas._touchListenersAdded = true;
    
    // Prevent default touch behaviors on canvas
    canvas.addEventListener('touchstart', function(e) {
      e.preventDefault();
      if (e.touches.length > 0) {
        var rect = canvas.getBoundingClientRect();
        var scaleX = canvas.width / rect.width;
        var scaleY = canvas.height / rect.height;
        
        if (typeof window !== 'undefined') {
          // Clear any existing timeout
          if (window._touchTimeout) {
            clearTimeout(window._touchTimeout);
          }
          
          window._lastInputX = Math.round((e.touches[0].clientX - rect.left) * scaleX);
          window._lastInputY = Math.round((e.touches[0].clientY - rect.top) * scaleY);
          window._inputActive = true;
          
          // Set a timeout to automatically reset touch state if touchend doesn't fire
          window._touchTimeout = setTimeout(function() {
            window._inputActive = false;
            window._touchTimeout = null;
          }, 500); // Much shorter 0.5 second timeout
        }
      }
    }, { passive: false });
    
    canvas.addEventListener('touchmove', function(e) {
      e.preventDefault();
      if (e.touches.length > 0) {
        var rect = canvas.getBoundingClientRect();
        var scaleX = canvas.width / rect.width;
        var scaleY = canvas.height / rect.height;
        
        if (typeof window !== 'undefined') {
          window._lastInputX = Math.round((e.touches[0].clientX - rect.left) * scaleX);
          window._lastInputY = Math.round((e.touches[0].clientY - rect.top) * scaleY);
          window._inputActive = true;
        }
      }
    }, { passive: false });
    
    canvas.addEventListener('touchend', function(e) {
      e.preventDefault();
      if (typeof window !== 'undefined') {
        // Clear the timeout since touchend fired properly
        if (window._touchTimeout) {
          clearTimeout(window._touchTimeout);
          window._touchTimeout = null;
        }
        window._inputActive = false;
      }
    }, { passive: false });
    
    canvas.addEventListener('touchcancel', function(e) {
      e.preventDefault();
      if (typeof window !== 'undefined') {
        // Clear the timeout since touchcancel fired  
        if (window._touchTimeout) {
          clearTimeout(window._touchTimeout);
          window._touchTimeout = null;
        }
        window._inputActive = false;
      }
    }, { passive: false });
    

    return true;
  }
  return false;
}

// Initialize touch event listeners when the page loads
if (typeof document !== 'undefined') {
  // Try to setup immediately if DOM is already loaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupTouchListeners);
  } else {
    setupTouchListeners();
  }
  
  // Also try to setup periodically in case canvas is created later
  var setupInterval = setInterval(function() {
    if (setupTouchListeners()) {
      clearInterval(setupInterval);
    }
  }, 100);
  
  // Clear the interval after 10 seconds to avoid running forever
  setTimeout(function() {
    clearInterval(setupInterval);
  }, 10000);
}

var TruthByteLib = {
  get_canvas_width: function() {
    var canvas = document.getElementById("canvas");
    if (canvas) {
      return canvas.width;
    }
    // Better mobile fallback
    if (typeof window !== 'undefined') {
      if (window.visualViewport) {
        return window.visualViewport.width;
      }
      return window.innerWidth || document.documentElement.clientWidth;
    }
    return 800; // Fallback width
  },
  
  get_canvas_height: function() {
    var canvas = document.getElementById("canvas");
    if (canvas) {
      return canvas.height;
    }
    // Better mobile fallback
    if (typeof window !== 'undefined') {
      if (window.visualViewport) {
        return window.visualViewport.height;
      }
      return window.innerHeight || document.documentElement.clientHeight;
    }
    return 600; // Fallback height
  },

  // Touch/Mouse position workaround for raylib-zig WASM issues
  get_input_x: function() {
    if (typeof window !== 'undefined' && window._lastInputX !== undefined) {
      return window._lastInputX;
    }
    return 0;
  },

  get_input_y: function() {
    if (typeof window !== 'undefined' && window._lastInputY !== undefined) {
      return window._lastInputY;
    }
    return 0;
  },

  get_input_active: function() {
    if (typeof window !== 'undefined') {
      return window._inputActive || false;
    }
    return false;
  },
  
  // Initialize authentication by fetching a JWT token
  init_auth: function(callback_ptr) {
    console.log("🌐 JavaScript init_auth called");
    fetch("https://api.truthbyte.voidtalker.com/v1/session", {
      method: 'GET',
      mode: 'cors',
      headers: {
        'Content-Type': 'application/json'
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    })
    .then(data => {
      console.log("✅ Authentication response:", data);
      // Store token and session ID globally
      _authToken = data.token;
      _sessionId = data.session_id;
      
      console.log("🔔 Calling Zig auth callback with success");
      // Call Zig callback with success (1)
      if (callback_ptr) {
        dynCall_vi(callback_ptr, 1);
      }
    })
    .catch(error => {
      console.error('❌ Authentication initialization failed:', error);
      
      console.log("🔔 Calling Zig auth callback with failure");
      // Call Zig callback with failure (0)
      if (callback_ptr) {
        dynCall_vi(callback_ptr, 0);
      }
    });
  },

  get_session_id: function() {
    // Return the actual session ID from authentication
    var sessionId = _sessionId;
    var len = lengthBytesUTF8(sessionId) + 1;
    var ptr = _malloc(len);
    stringToUTF8(sessionId, ptr, len);
    return ptr;
  },
  
  get_session_id_len: function() {
    var sessionId = _sessionId;
    return lengthBytesUTF8(sessionId);
  },
  
  get_token: function() {
    // Return the actual JWT token from authentication
    var token = _authToken;
    var len = lengthBytesUTF8(token) + 1;
    var ptr = _malloc(len);
    stringToUTF8(token, ptr, len);
    return ptr;
  },
  
  get_token_len: function() {
    var token = _authToken;
    return lengthBytesUTF8(token);
  },
    
  get_invited_shown: function () {
    return 0;
  },

  set_invited_shown: function(val) {
    // ToDo: Implement this
  },

  // Fetch questions from the backend
  // Parameters: num_questions (optional), tag (optional), user_id_ptr, user_id_len, callback_ptr
  fetch_questions: function(num_questions, tag_ptr, tag_len, user_id_ptr, user_id_len, callback_ptr) {
    console.log("🌐 JavaScript fetch_questions called");
    var url = "https://api.truthbyte.voidtalker.com/v1/fetch-questions";
    var params = new URLSearchParams();
    
    if (num_questions > 0) {
      params.append('num_questions', num_questions.toString());
    }
    
    if (tag_ptr && tag_len > 0) {
      var tag = UTF8ToString(tag_ptr, tag_len);
      params.append('tag', tag);
    }
    
    if (params.toString()) {
      url += '?' + params.toString();
    }
    
    var headers = {
      'Content-Type': 'application/json'
    };
    
    // Add Authorization header if we have a token
    if (_authToken) {
      headers['Authorization'] = 'Bearer ' + _authToken;
    }
    
    // Add User ID header from Zig
    var userId = user_id_ptr && user_id_len > 0 ? UTF8ToString(user_id_ptr, user_id_len) : '';
    console.log("🔍 About to send request with User ID from Zig:", userId);
    headers['X-User-ID'] = userId;
    
    fetch(url, {
      method: 'GET',
      mode: 'cors',
      headers: headers
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    })
    .then(data => {
      console.log("✅ Questions response:", data);
      // Convert response to JSON string and pass to Zig callback
      var jsonStr = JSON.stringify(data);
      var len = lengthBytesUTF8(jsonStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(jsonStr, ptr, len);
      
      console.log("🔔 Calling Zig questions callback with success");
      // Call Zig callback with success (1), data pointer, and length
      dynCall_viii(callback_ptr, 1, ptr, len);
      _free(ptr);
    })
    .catch(error => {
      console.error('❌ Fetch questions error:', error);
      var errorStr = error.message || 'Unknown error';
      var len = lengthBytesUTF8(errorStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(errorStr, ptr, len);
      
      // Call Zig callback with failure (0), error pointer, and length
      dynCall_viii(callback_ptr, 0, ptr, len);
      _free(ptr);
    });
  },

  // Submit answers to the backend
  // Parameters: answers_json_ptr, answers_json_len, user_id_ptr, user_id_len, callback_ptr
  submit_answers: function(answers_json_ptr, answers_json_len, user_id_ptr, user_id_len, callback_ptr) {
    var answersJson = UTF8ToString(answers_json_ptr, answers_json_len);
    
    var answers;
    
    try {
      answers = JSON.parse(answersJson);
    } catch (e) {
      var errorStr = 'Invalid JSON format';
      var len = lengthBytesUTF8(errorStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(errorStr, ptr, len);
      dynCall_viii(callback_ptr, 0, ptr, len);
      _free(ptr);
      return;
    }
    
    var headers = {
      'Content-Type': 'application/json'
    };
    
    // Add Authorization header if we have a token
    if (_authToken) {
      headers['Authorization'] = 'Bearer ' + _authToken;
    }
    
    // Add User ID header from Zig
    headers['X-User-ID'] = user_id_ptr && user_id_len > 0 ? UTF8ToString(user_id_ptr, user_id_len) : '';
    
    fetch("https://api.truthbyte.voidtalker.com/v1/submit-answers", {
      method: 'POST',
      mode: 'cors',
      headers: headers,
      body: JSON.stringify(answers)
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    })
    .then(data => {
      // Convert response to JSON string and pass to Zig callback
      var jsonStr = JSON.stringify(data);
      var len = lengthBytesUTF8(jsonStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(jsonStr, ptr, len);
      
      // Call Zig callback with success (1), data pointer, and length
      dynCall_viii(callback_ptr, 1, ptr, len);
      _free(ptr);
    })
    .catch(error => {
      var errorStr = error.message || 'Unknown error';
      var len = lengthBytesUTF8(errorStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(errorStr, ptr, len);
      
      // Call Zig callback with failure (0), error pointer, and length
      dynCall_viii(callback_ptr, 0, ptr, len);
      _free(ptr);
    });
  },

  // Propose a new question to the backend
  // Parameters: question_json_ptr, question_json_len, user_id_ptr, user_id_len, callback_ptr
  propose_question: function(question_json_ptr, question_json_len, user_id_ptr, user_id_len, callback_ptr) {
    var questionJson = UTF8ToString(question_json_ptr, question_json_len);
    var question;
    
    try {
      question = JSON.parse(questionJson);
    } catch (e) {
      var errorStr = 'Invalid JSON format';
      var len = lengthBytesUTF8(errorStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(errorStr, ptr, len);
      dynCall_viii(callback_ptr, 0, ptr, len);
      _free(ptr);
      return;
    }
    
    var headers = {
      'Content-Type': 'application/json'
    };
    
    // Add Authorization header if we have a token
    if (_authToken) {
      headers['Authorization'] = 'Bearer ' + _authToken;
    }
    
    // Add User ID header from Zig
    headers['X-User-ID'] = user_id_ptr && user_id_len > 0 ? UTF8ToString(user_id_ptr, user_id_len) : '';
    
    fetch("https://api.truthbyte.voidtalker.com/v1/propose-question", {
      method: 'POST',
      mode: 'cors',
      headers: headers,
      body: JSON.stringify(question)
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    })
    .then(data => {
      // Convert response to JSON string and pass to Zig callback
      var jsonStr = JSON.stringify(data);
      var len = lengthBytesUTF8(jsonStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(jsonStr, ptr, len);
      
      // Call Zig callback with success (1), data pointer, and length
      dynCall_viii(callback_ptr, 1, ptr, len);
      _free(ptr);
    })
    .catch(error => {
      var errorStr = error.message || 'Unknown error';
      var len = lengthBytesUTF8(errorStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(errorStr, ptr, len);
      
      // Call Zig callback with failure (0), error pointer, and length
      dynCall_viii(callback_ptr, 0, ptr, len);
      _free(ptr);
    });
  },

  // Debug function to test JWT token validation
  // Parameters: callback_ptr
  auth_ping: function(callback_ptr) {
    var headers = {
      'Content-Type': 'application/json'
    };
    
    // Add Authorization header if we have a token
    if (_authToken) {
      headers['Authorization'] = 'Bearer ' + _authToken;
    }
    
    // auth_ping doesn't require user ID header
    
    fetch("https://api.truthbyte.voidtalker.com/v1/ping", {
      method: 'GET',
      mode: 'cors',
      headers: headers
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    })
    .then(data => {
      // Convert response to JSON string and pass to Zig callback
      var jsonStr = JSON.stringify(data);
      var len = lengthBytesUTF8(jsonStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(jsonStr, ptr, len);
      
      // Call Zig callback with success (1), data pointer, and length
      dynCall_viii(callback_ptr, 1, ptr, len);
      _free(ptr);
    })
    .catch(error => {
      var errorStr = error.message || 'Unknown error';
      var len = lengthBytesUTF8(errorStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(errorStr, ptr, len);
      
      // Call Zig callback with failure (0), error pointer, and length
      dynCall_viii(callback_ptr, 0, ptr, len);
      _free(ptr);
    });
  },

  // Fetch user data from the backend
  // Parameters: user_id_ptr, user_id_len, callback_ptr
  fetch_user: function(user_id_ptr, user_id_len, callback_ptr) {
    console.log("🌐 JavaScript fetch_user called");
    var headers = {
      'Content-Type': 'application/json'
    };
    
    // Add Authorization header if we have a token
    if (_authToken) {
      headers['Authorization'] = 'Bearer ' + _authToken;
    }
    
    // Add User ID header from Zig
    headers['X-User-ID'] = user_id_ptr && user_id_len > 0 ? UTF8ToString(user_id_ptr, user_id_len) : '';
    
    fetch("https://api.truthbyte.voidtalker.com/v1/user", {
      method: 'GET',
      mode: 'cors',
      headers: headers
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    })
    .then(data => {
      console.log("✅ User response:", data);
      // Convert response to JSON string and pass to Zig callback
      var jsonStr = JSON.stringify(data);
      var len = lengthBytesUTF8(jsonStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(jsonStr, ptr, len);
      
      console.log("🔔 Calling Zig user callback with success");
      // Call Zig callback with success (1), data pointer, and length
      dynCall_viii(callback_ptr, 1, ptr, len);
      _free(ptr);
    })
    .catch(error => {
      console.error('❌ Fetch user error:', error);
      var errorStr = error.message || 'Unknown error';
      var len = lengthBytesUTF8(errorStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(errorStr, ptr, len);
      
      // Call Zig callback with failure (0), error pointer, and length
      dynCall_viii(callback_ptr, 0, ptr, len);
      _free(ptr);
    });
  }
};

// Add localStorage interface functions to the library
TruthByteLib.js_get_local_storage = js_get_local_storage;
TruthByteLib.js_set_local_storage = js_set_local_storage;

mergeInto(LibraryManager.library, TruthByteLib);
