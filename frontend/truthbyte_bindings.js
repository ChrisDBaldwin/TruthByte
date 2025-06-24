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
    
  get_invited_shown: function () {
    return 0;
  },

  set_invited_shown: function(val) {
    // ToDo: Implement this
  },

  // Fetch questions from the backend
  // Parameters: num_questions (optional), tag (optional), user_id_ptr, user_id_len, callback_ptr
  fetch_questions: function(num_questions, tag_ptr, tag_len, user_id_ptr, user_id_len, callback_ptr) {
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
    // Convert Zig string to JavaScript string
    var placeholder = '';
    if (placeholder_ptr && placeholder_len > 0) {
      placeholder = UTF8ToString(placeholder_ptr, placeholder_len);
    }

    // Remove any existing input first
    var existingInput = document.getElementById('truthbyte-text-input');
    if (existingInput) {
      existingInput.remove();
    }
    
    // Try contenteditable div instead of input - sometimes works better on mobile
    var textInput = document.createElement('div');
    textInput.contentEditable = true;
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
    textInput.style.opacity = '1'; // Fully visible for debugging
    textInput.style.display = 'block';
    textInput.style.visibility = 'visible';
    textInput.style.pointerEvents = 'auto';
    textInput.style.backgroundColor = 'rgba(255, 255, 255, 0.9)';
    textInput.style.border = '2px solid red'; // Red border to distinguish from input
    textInput.style.color = 'black';
    textInput.style.lineHeight = height + 'px'; // Vertical center
    textInput.style.paddingLeft = '8px';
    textInput.style.boxSizing = 'border-box';
    
    // Add placeholder functionality for contenteditable
    if (placeholder) {
      textInput.setAttribute('data-placeholder', placeholder);
      textInput.innerHTML = '<span style="color: #999; pointer-events: none;">' + placeholder + '</span>';
    }
    
        // Add event listeners
    textInput.addEventListener('keydown', function(e) {
      if (e.key === 'Enter' || e.key === 'Return') {
        e.preventDefault();
        e.stopPropagation();
        textInput.blur();
        TruthByteLib.hideTextInput();
        return;
      }
      
      // MANUAL BACKSPACE HANDLING for iOS Safari bug
      if (e.key === 'Backspace') {
        e.preventDefault(); // Prevent default (broken) backspace
        
        var currentText = textInput.textContent || '';
        if (currentText.length > 0) {
          // Remove last character manually
          var newText = currentText.slice(0, -1);
          textInput.textContent = newText;
          
          // Position cursor at end
          if (newText.length > 0) {
            var range = document.createRange();
            var sel = window.getSelection();
            range.setStart(textInput.firstChild, newText.length);
            range.collapse(true);
            sel.removeAllRanges();
            sel.addRange(range);
          }
          
          // Trigger input event manually for synchronization
          var inputEvent = new Event('input', { bubbles: true });
          textInput.dispatchEvent(inputEvent);
        }
        return;
      }
    });
  
        textInput.addEventListener('input', function(e) {
      // Remove placeholder when typing
      var placeholder_span = textInput.querySelector('span[style*="color: #999"]');
      if (placeholder_span && textInput.textContent.length > 0) {
        placeholder_span.remove();
      }
    });
    
    textInput.addEventListener('focus', function(e) {
      // Remove placeholder on focus
      var placeholder_span = textInput.querySelector('span[style*="color: #999"]');
      if (placeholder_span) {
        placeholder_span.remove();
        textInput.textContent = '';
      }
    });
    
    textInput.addEventListener('blur', function(e) {
      // Add placeholder back if empty
      if (textInput.textContent.trim() === '' && placeholder) {
        textInput.innerHTML = '<span style="color: #999; pointer-events: none;">' + placeholder + '</span>';
      }
    });
     
     // Add click-outside-to-hide functionality
     var clickOutsideHandler = function(e) {
       // Check if click is outside the text input
       if (!textInput.contains(e.target)) {
         TruthByteLib.hideTextInput();
         // Remove this specific event listener when hiding
         document.removeEventListener('click', clickOutsideHandler, true);
       }
     };
     
     // Add the click listener with capture=true to catch clicks before they bubble
     setTimeout(function() {
       document.addEventListener('click', clickOutsideHandler, true);
     }, 100); // Small delay to avoid immediate hiding from the click that showed the input
     
     document.body.appendChild(textInput);
    
    // Focus the contenteditable div
    setTimeout(function() {
      textInput.focus();
      
      // Move cursor to end if there's content
      if (textInput.textContent.length > 0) {
        var range = document.createRange();
        var sel = window.getSelection();
        range.setStart(textInput, textInput.childNodes.length);
        range.collapse(true);
        sel.removeAllRanges();
        sel.addRange(range);
      }
    }, 100);
    
    return true;
  },

  hideTextInput: function() {
    var textInput = document.getElementById('truthbyte-text-input');
    if (textInput) {
      textInput.style.display = 'none';
      textInput.style.visibility = 'hidden';
      textInput.style.pointerEvents = 'none';
      textInput.blur();
    }
    return true;
  },

  getTextInputValue: function() {
    var textInput = document.getElementById('truthbyte-text-input');
    if (!textInput) {
      return null;
    }
    
    // Use textContent for contenteditable divs, value for inputs
    var value = textInput.textContent || textInput.value || '';
    
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
    
    // Use textContent for contenteditable divs, value for inputs
    var value = textInput.textContent || textInput.value || '';
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
      // Clear both textContent and value to support both input and contenteditable
      textInput.textContent = '';
      textInput.value = '';
      
      // Re-add placeholder if it exists
      var placeholder = textInput.getAttribute('data-placeholder');
      if (placeholder && textInput.contentEditable === 'true') {
        textInput.innerHTML = '<span style="color: #999; pointer-events: none;">' + placeholder + '</span>';
      }
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
    
    if (textInput.contentEditable === 'true') {
      // For contenteditable div
      textInput.textContent = value;
      
      // Move cursor to end
      setTimeout(function() {
        if (textInput === document.activeElement && value.length > 0) {
          var range = document.createRange();
          var sel = window.getSelection();
          range.setStart(textInput.firstChild || textInput, value.length);
          range.collapse(true);
          sel.removeAllRanges();
          sel.addRange(range);
        }
      }, 10);
    } else {
      // For regular input
      textInput.value = value;
      
      setTimeout(function() {
        if (textInput === document.activeElement) {
          textInput.setSelectionRange(value.length, value.length);
        }
      }, 10);
    }
    
    return true;
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
