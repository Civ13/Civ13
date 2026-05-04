const chatContainer = document.getElementById('chat-container');
const messagesContainer = document.getElementById('messages');

/**
 * Receives a message from BYOND.
 * @param {string|object} data - The message text or a JSON object.
 */
function receiveMessage(data) {
    let messageHtml = '';
    
    if (typeof data === 'string') {
        messageHtml = data;
    } else if (typeof data === 'object' && data.message) {
        messageHtml = data.message;
    }

    if (!messageHtml) return;

    const messageDiv = document.createElement('div');
    messageDiv.className = 'message';
    messageDiv.innerHTML = messageHtml;
    
    messagesContainer.appendChild(messageDiv);
    
    // Smooth auto-scroll
    chatContainer.scrollTop = chatContainer.scrollHeight;

    // Keep memory usage in check by trimming old messages (optional, set to 500)
    if (messagesContainer.children.length > 500) {
        messagesContainer.removeChild(messagesContainer.firstChild);
    }
}

// Expose to global scope for BYOND
window.receiveMessage = receiveMessage;

// Notify BYOND that we are ready
window.location.href = 'byond://?chat_ready=1';
