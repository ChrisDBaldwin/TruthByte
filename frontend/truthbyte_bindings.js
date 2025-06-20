// JWT Authentication variables - declared outside the library object
var _authToken = null;
var _sessionId = null;

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
      console.log('touchstart event fired, touches:', e.touches.length);
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
            console.log('TIMEOUT: Force resetting stuck touch state');
            window._inputActive = false;
            window._touchTimeout = null;
          }, 2000); // 2 second timeout
          
          console.log('Touch start:', window._lastInputX, window._lastInputY, 'inputActive:', window._inputActive);
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
          
          console.log('Touch move:', window._lastInputX, window._lastInputY, 'inputActive:', window._inputActive);
        }
      }
    }, { passive: false });
    
        canvas.addEventListener('touchend', function(e) {
      console.log('touchend event fired');
      e.preventDefault();
      if (typeof window !== 'undefined') {
        // Clear the timeout since touchend fired properly
        if (window._touchTimeout) {
          clearTimeout(window._touchTimeout);
          window._touchTimeout = null;
        }
        window._inputActive = false;
      }
      console.log('Touch end, inputActive:', typeof window !== 'undefined' ? window._inputActive : 'undefined');
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
      console.log('Touch cancel, inputActive:', typeof window !== 'undefined' ? window._inputActive : 'undefined');
    }, { passive: false });
    
    console.log('Touch event listeners added to canvas');
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
  
  // Debug function to log current touch state
  debug_touch_state: function() {
    if (typeof window !== 'undefined') {
      console.log('JS Touch State - X:', window._lastInputX, 'Y:', window._lastInputY, 'Active:', window._inputActive);
    }
  },
  
  // Initialize authentication by fetching a JWT token
  init_auth: function(callback_ptr) {
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
      // Store token and session ID globally
      _authToken = data.token;
      _sessionId = data.session_id;
      
      console.log('Authentication initialized successfully');
      
      // Call Zig callback with success (1)
      if (callback_ptr) {
        dynCall_vi(callback_ptr, 1);
      }
    })
    .catch(error => {
      console.error('Authentication initialization failed:', error);
      
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
    console.log("invited shown:", !!val);
  },

  // Fetch questions from the backend
  // Parameters: num_questions (optional), tag (optional), callback_ptr
  fetch_questions: function(num_questions, tag_ptr, tag_len, callback_ptr) {
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
      console.error('Fetch questions error:', error);
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
  // Parameters: answers_json_ptr, answers_json_len, callback_ptr
  submit_answers: function(answers_json_ptr, answers_json_len, callback_ptr) {
    console.log('🌐 submit_answers called with:', { answers_json_len, callback_ptr });
    
    var answersJson = UTF8ToString(answers_json_ptr, answers_json_len);
    console.log('📝 Received JSON:', answersJson);
    
    var answers;
    
    try {
      answers = JSON.parse(answersJson);
      console.log('✅ JSON parsed successfully:', answers);
    } catch (e) {
      console.error('❌ Invalid JSON for answers:', e);
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
      console.log('🔐 Using auth token:', _authToken.substring(0, 20) + '...');
    } else {
      console.warn('⚠️ No auth token available');
    }
    
    console.log('🚀 Making POST request to /v1/submit-answers');
    console.log('📤 Headers:', headers);
    console.log('📤 Body:', JSON.stringify(answers));
    
    fetch("https://api.truthbyte.voidtalker.com/v1/submit-answers", {
      method: 'POST',
      mode: 'cors',
      headers: headers,
      body: JSON.stringify(answers)
    })
    .then(response => {
      console.log('📨 Response received:', response.status, response.statusText);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    })
    .then(data => {
      console.log('✅ Submit answers successful:', data);
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
      console.error('❌ Submit answers error:', error);
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
  // Parameters: question_json_ptr, question_json_len, callback_ptr
  propose_question: function(question_json_ptr, question_json_len, callback_ptr) {
    var questionJson = UTF8ToString(question_json_ptr, question_json_len);
    var question;
    
    try {
      question = JSON.parse(questionJson);
    } catch (e) {
      console.error('Invalid JSON for question:', e);
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
      console.error('Propose question error:', error);
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
      console.error('Auth ping error:', error);
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

mergeInto(LibraryManager.library, TruthByteLib);
