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

// Touch event handling is done in shell.html to avoid duplicate handlers

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
      
      // Call Zig callback with success (1)
      if (callback_ptr) {
        dynCall_vi(callback_ptr, 1);
      }
    })
    .catch(error => {
      console.error('❌ Authentication initialization failed:', error);
      
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

  // Get current UTC date in YYYY-MM-DD format
  get_current_date: function() {
    var now = new Date();
    var year = now.getUTCFullYear();
    var month = String(now.getUTCMonth() + 1).padStart(2, '0'); // getUTCMonth() returns 0-11
    var day = String(now.getUTCDate()).padStart(2, '0');
    var dateStr = year + '-' + month + '-' + day;
    
    var len = lengthBytesUTF8(dateStr) + 1;
    var ptr = _malloc(len);
    stringToUTF8(dateStr, ptr, len);
    return ptr;
  },

  get_current_date_len: function() {
    var now = new Date();
    var year = now.getUTCFullYear();
    var month = String(now.getUTCMonth() + 1).padStart(2, '0');
    var day = String(now.getUTCDate()).padStart(2, '0');
    var dateStr = year + '-' + month + '-' + day;
    return lengthBytesUTF8(dateStr);
  },

  // Fetch questions with category and difficulty support
  // Parameters: num_questions, category_ptr, category_len, difficulty, user_id_ptr, user_id_len, callback_ptr
  fetch_questions: function(num_questions, category_ptr, category_len, difficulty, user_id_ptr, user_id_len, callback_ptr) {
    var url = "https://api.truthbyte.voidtalker.com/v1/fetch-questions";
    var params = new URLSearchParams();
    
    if (num_questions > 0) {
      params.append('num_questions', num_questions.toString());
    }
    
    if (category_ptr && category_len > 0) {
      var category = UTF8ToString(category_ptr, category_len);
      params.append('category', category);
    }
    
    if (difficulty > 0 && difficulty <= 5) {
      params.append('difficulty', difficulty.toString());
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

  // Fetch available categories from the backend
  // Parameters: user_id_ptr, user_id_len, callback_ptr
  fetch_categories: function(user_id_ptr, user_id_len, callback_ptr) {
    var headers = {
      'Content-Type': 'application/json'
    };
    
    // Add Authorization header if we have a token
    if (_authToken) {
      headers['Authorization'] = 'Bearer ' + _authToken;
    }
    
    // Add User ID header from Zig
    var userId = user_id_ptr && user_id_len > 0 ? UTF8ToString(user_id_ptr, user_id_len) : '';
    headers['X-User-ID'] = userId;
    
    fetch("https://api.truthbyte.voidtalker.com/v1/get-categories", {
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
      console.error('❌ Fetch categories error:', error);
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
      console.error('❌ Fetch user error:', error);
      var errorStr = error.message || 'Unknown error';
      var len = lengthBytesUTF8(errorStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(errorStr, ptr, len);
      
      // Call Zig callback with failure (0), error pointer, and length
      dynCall_viii(callback_ptr, 0, ptr, len);
      _free(ptr);
    });
  },

  // --- Text Input Management (Single Persistent Field) ---
  
  showTextInput: function(x, y, width, height, placeholder_ptr, placeholder_len) {
    // Remove any existing input first
    var existingInput = document.getElementById('truthbyte-text-input');
    if (existingInput) {
      // Force immediate blur before removal
      if (document.activeElement === existingInput) {
        existingInput.blur();
        document.body.focus(); // Focus something else
      }
      existingInput.remove();
    }
    
    // Small delay to ensure cleanup is complete before creating new input
    setTimeout(function() {
      // Create a simple text input that only accepts plain text
      var textInput = document.createElement('input');
      textInput.type = 'text';
      textInput.id = 'truthbyte-text-input';
      
      // Styling for contenteditable div
      textInput.style.position = 'absolute';
      textInput.style.zIndex = '10000';
      textInput.style.fontSize = '16px';
      textInput.style.fontFamily = 'Arial, sans-serif';
      textInput.style.outline = 'none'; // Remove focus outline
      textInput.style.whiteSpace = 'nowrap'; // Prevent line breaks
      textInput.style.overflow = 'hidden'; // Hide overflow
      
      // Position the input exactly over the game's input box area
      textInput.style.left = x + 'px';
      textInput.style.top = y + 'px';
      textInput.style.width = width + 'px';
      textInput.style.height = height + 'px';
      textInput.style.opacity = '0.0';
      textInput.style.display = 'block';
      textInput.style.visibility = 'visible';
      textInput.style.pointerEvents = 'none'; // Start non-interactive
      textInput.style.backgroundColor = 'transparent';
      textInput.style.border = 'none'; // No border at all
      textInput.style.outline = 'none'; // No outline
      textInput.style.color = 'transparent';
      textInput.style.caretColor = 'transparent'; // Hide cursor too
      textInput.style.lineHeight = height + 'px'; // Vertical center
      textInput.style.paddingLeft = '8px';
      textInput.style.boxSizing = 'border-box';
      
      // Add event listeners
      textInput.addEventListener('keydown', function(e) {
        if (e.key === 'Enter' || e.key === 'Return') {
          e.preventDefault();
          e.stopPropagation();
          textInput.blur();
          return;
        }
        // Handle Escape key to cancel input
        if (e.key === 'Escape') {
          e.preventDefault();
          e.stopPropagation();
          textInput.blur();
          TruthByteLib.hideTextInput();
          return;
        }
      });
        
      // Handle mousedown on the input specially
      textInput.addEventListener('mousedown', function(e) {
        // If clicking inside input, let it handle normally
        if (document.activeElement === textInput) {
          e.stopPropagation(); // Prevent double-handling
        }
      });

      // Handle click on the input specially
      textInput.addEventListener('click', function(e) {
        // If clicking inside input, let it handle normally
        if (document.activeElement === textInput) {
          e.stopPropagation(); // Prevent double-handling
        }
      });
      
      // SECURITY: Block paste events with binary/malicious content
      textInput.addEventListener('paste', function(e) {
        e.preventDefault();
        
        var clipboardData = e.clipboardData || window.clipboardData;
        if (!clipboardData) return;
              
        // Get pasted text
        var pastedText = clipboardData.getData('text/plain') || clipboardData.getData('text');
        if (!pastedText) return;
        
        // Security validation
        function containsSuspiciousContent(text) {
          // Check for binary content (non-printable characters)
          for (var i = 0; i < text.length; i++) {
            var charCode = text.charCodeAt(i);
            if (charCode < 32 && charCode !== 9 && charCode !== 10 && charCode !== 13) {
              return true; // Contains binary/control characters
            }
          }
          
          // Check for suspicious patterns
          var suspiciousPatterns = [
            '<script', 'javascript:', 'data:', 'vbscript:', 'onload=', 'onerror=',
            'onclick=', 'eval(', 'document.', 'window.', '\\x', '\\u',
            '%3c', '%3e', '&#'
          ];
          
          // Check for placeholder/invalid content
          var invalidPatterns = [
            'question', 'enter question', 'type question', 'your question',
            'question here', 'ask question', 'placeholder', 'example',
            'sample', 'test', 'testing', 'asdf', 'qwerty', 'lorem ipsum'
          ];
          
          var lowerText = text.toLowerCase();
          
          for (var i = 0; i < suspiciousPatterns.length; i++) {
            if (lowerText.indexOf(suspiciousPatterns[i]) !== -1) {
              return true;
            }
          }
          
          for (var i = 0; i < invalidPatterns.length; i++) {
            if (lowerText.indexOf(invalidPatterns[i]) !== -1) {
              return true;
            }
          }
          
          return false;
        }
        
        // Block suspicious content
        if (containsSuspiciousContent(pastedText)) {
          return;
        }
        
        // Sanitize and limit length
        var sanitized = '';
        var maxLength = 200; // Question max length
        var consecutiveSpaces = 0;
        
        for (var i = 0; i < Math.min(pastedText.length, maxLength); i++) {
          var char = pastedText[i];
          var charCode = char.charCodeAt(0);
          
          // Only allow printable ASCII
          if (charCode >= 32 && charCode <= 126) {
            if (char === ' ') {
              consecutiveSpaces++;
              if (consecutiveSpaces <= 2) {
                sanitized += char;
              }
            } else {
              consecutiveSpaces = 0;
              sanitized += char;
            }
          }
        }
        
        // Set the sanitized text directly to input value
        if (sanitized.length > 0) {
          textInput.value = sanitized;
        }
      });
      
      // Simple input validation on typing
      textInput.addEventListener('input', function(e) {
        // Limit length and validate characters in real-time
        var value = textInput.value;
        var sanitized = '';
        
        for (var i = 0; i < Math.min(value.length, 200); i++) {
          var charCode = value.charCodeAt(i);
          if (charCode >= 32 && charCode <= 126) {
            sanitized += value[i];
          }
        }
        
        if (sanitized !== value) {
          textInput.value = sanitized;
        }
      });
      
      // SECURITY: Block drag and drop of files/images
      textInput.addEventListener('dragover', function(e) {
        e.preventDefault();
        e.stopPropagation();
      });
      
      textInput.addEventListener('drop', function(e) {
        e.preventDefault();
        e.stopPropagation();
        
        var files = e.dataTransfer.files;
        if (files && files.length > 0) {
          console.warn('🚫 File drop blocked - only text input allowed');
          return;
        }
        
        // Allow text drops but validate them
        var droppedText = e.dataTransfer.getData('text/plain');
        if (droppedText) {
          // Simple sanitization
          var sanitized = '';
          for (var i = 0; i < Math.min(droppedText.length, 200); i++) {
            var charCode = droppedText.charCodeAt(i);
            if (charCode >= 32 && charCode <= 126) {
              sanitized += droppedText[i];
            }
          }
          textInput.value = sanitized;
        }
      });
       
       document.body.appendChild(textInput);
      
      // For touch users, focus the input immediately to make it interactive
      // For mouse users, it stays non-interactive (pointerEvents: 'none')
      setTimeout(function() {
        if (textInput && textInput.parentNode) {
          textInput.focus();
        }
      }, 50);
    }, 10);
    
    return true;
  },

  hideTextInput: function() {
    var textInput = document.getElementById('truthbyte-text-input');
    if (textInput) {
      // Force immediate blur before removal
      if (document.activeElement === textInput) {
        textInput.blur();
        document.body.focus(); // Focus something else
      }
      
      // Completely remove the element to prevent any click interference
      textInput.remove();
    }
    return true;
  },

  // Update text input position (for screen resize)
  updateTextInputPosition: function(x, y, width, height) {
    var textInput = document.getElementById('truthbyte-text-input');
    if (textInput && textInput.style.display !== 'none') {
      textInput.style.left = x + 'px';
      textInput.style.top = y + 'px';
      textInput.style.width = width + 'px';
      textInput.style.height = height + 'px';
    }
    return true;
  },

  getTextInputValue: function() {
    var textInput = document.getElementById('truthbyte-text-input');
    if (!textInput) {
      return null;
    }
    
    // Use value for regular input elements
    var value = textInput.value || '';
    
    // Allocate memory for the string and copy it
    var len = lengthBytesUTF8(value) + 1;
    var ptr = _malloc(len);
    stringToUTF8(value, ptr, len);
    return ptr;
  },

  getTextInputValueLength: function() {
    var textInput = document.getElementById('truthbyte-text-input');
    if (!textInput) {
      return 0;
    }
    
    // Use value for regular input elements
    var value = textInput.value || '';
    return lengthBytesUTF8(value);
  },

  isTextInputFocused: function() {
    var textInput = document.getElementById('truthbyte-text-input');
    if (!textInput) {
      return false;
    }
    
    return document.activeElement === textInput;
  },

  clearTextInput: function() {
    var textInput = document.getElementById('truthbyte-text-input');
    if (textInput) {
      // Clear the input value
      textInput.value = '';
    }
    return true;
  },

  setTextInputValue: function(value_ptr, value_len) {
    var textInput = document.getElementById('truthbyte-text-input');
    if (!textInput) {
      return false;
    }
    
    var value = '';
    if (value_ptr && value_len > 0) {
      value = UTF8ToString(value_ptr, value_len);
    }
    
    // For regular input element
    textInput.value = value;
    
    // Move cursor to end
    setTimeout(function() {
      if (textInput === document.activeElement) {
        textInput.setSelectionRange(value.length, value.length);
      }
    }, 10);
    
    return true;
  },

  // Fetch daily questions for the current day
  // Parameters: user_id_ptr, user_id_len, callback_ptr
  fetch_daily_questions: function(user_id_ptr, user_id_len, callback_ptr) {
    var headers = {
      'Content-Type': 'application/json'
    };
    
    // Add Authorization header if we have a token
    if (_authToken) {
      headers['Authorization'] = 'Bearer ' + _authToken;
    }
    
    // Add User ID header from Zig
    var userId = user_id_ptr && user_id_len > 0 ? UTF8ToString(user_id_ptr, user_id_len) : '';
    headers['X-User-ID'] = userId;
    
    fetch("https://api.truthbyte.voidtalker.com/v1/fetch-daily-questions", {
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
      console.error('❌ Fetch daily questions error:', error);
      var errorStr = error.message || 'Unknown error';
      var len = lengthBytesUTF8(errorStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(errorStr, ptr, len);
      
      // Call Zig callback with failure (0), error pointer, and length
      dynCall_viii(callback_ptr, 0, ptr, len);
      _free(ptr);
    });
  },

  // Submit daily answers to the backend
  // Parameters: answers_json_ptr, answers_json_len, user_id_ptr, user_id_len, callback_ptr
  submit_daily_answers: function(answers_json_ptr, answers_json_len, user_id_ptr, user_id_len, callback_ptr) {
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
    
    fetch("https://api.truthbyte.voidtalker.com/v1/submit-daily-answers", {
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
      console.error('❌ Submit daily answers error:', error);
      var errorStr = error.message || 'Unknown error';
      var len = lengthBytesUTF8(errorStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(errorStr, ptr, len);
      
      // Call Zig callback with failure (0), error pointer, and length
      dynCall_viii(callback_ptr, 0, ptr, len);
      _free(ptr);
    });
  },

  // Legacy compatibility (redirect to new system)
  createTextInput: function(x, y, width, height, placeholder_ptr, placeholder_len) {
    return this.showTextInput(x, y, width, height, placeholder_ptr, placeholder_len);
  },

};

// Add localStorage interface functions to the library
TruthByteLib.js_get_local_storage = js_get_local_storage;
TruthByteLib.js_set_local_storage = js_set_local_storage;

mergeInto(LibraryManager.library, TruthByteLib);
