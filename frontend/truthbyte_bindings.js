mergeInto(LibraryManager.library, {
  // TruthByte API Configuration
  API_BASE: "https://api.voidtalker.com/dev", // TODO: Make this dynamic
  
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
  },

  // Fetch questions from the backend
  // Parameters: num_questions (optional), tag (optional), callback_ptr
  fetch_questions: function(num_questions, tag_ptr, tag_len, callback_ptr) {
    var url = `${this.API_BASE}/v1/fetch-questions`;
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
    
    fetch(url, {
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
    var answersJson = UTF8ToString(answers_json_ptr, answers_json_len);
    var answers;
    
    try {
      answers = JSON.parse(answersJson);
    } catch (e) {
      console.error('Invalid JSON for answers:', e);
      var errorStr = 'Invalid JSON format';
      var len = lengthBytesUTF8(errorStr) + 1;
      var ptr = _malloc(len);
      stringToUTF8(errorStr, ptr, len);
      dynCall_viii(callback_ptr, 0, ptr, len);
      _free(ptr);
      return;
    }
    
    fetch(`${this.API_BASE}/v1/submit-answers`, {
      method: 'POST',
      mode: 'cors',
      headers: {
        'Content-Type': 'application/json'
      },
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
      console.error('Submit answers error:', error);
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
    
    fetch(`${this.API_BASE}/v1/propose-question`, {
      method: 'POST',
      mode: 'cors',
      headers: {
        'Content-Type': 'application/json'
      },
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
  }
});
