// Construction Job UI Application
const app = {
    // State Variables
    isVisible: false,
    currentRank: 'Apprentice',
    xpProgress: 0,
    nextRank: 'Skilled Worker',
    tools: [],
    
    // Initialize the application
    init: function() {
        // Set up event listeners
        window.addEventListener('message', this.handleMessage.bind(this));
        
        // Initialize UI components
        this.updateRankInfo();
    },
    
    // Handle incoming messages from the game
    handleMessage: function(event) {
        const data = event.data;
        
        switch (data.action) {
            case 'show':
                this.showUI();
                break;
                
            case 'hide':
                this.hideUI();
                break;
                
            case 'updateRank':
                this.updateRankInfo(data.rank, data.xpProgress, data.nextRank);
                break;
                
            case 'updateTools':
                this.updateToolInfo(data.tools);
                break;
                
            case 'notification':
                this.showNotification(data.message, data.type);
                break;
        }
    },
    
    // Show the main UI
    showUI: function() {
        document.getElementById('main-container').classList.remove('hidden');
        this.isVisible = true;
    },
    
    // Hide the main UI
    hideUI: function() {
        document.getElementById('main-container').classList.add('hidden');
        this.isVisible = false;
    },
    
    // Update rank information display
    updateRankInfo: function(rank, xpProgress, nextRank) {
        if (rank) this.currentRank = rank;
        if (xpProgress !== undefined) this.xpProgress = xpProgress;
        if (nextRank) this.nextRank = nextRank;
        
        // Update UI elements
        document.getElementById('current-rank').textContent = this.currentRank;
        document.getElementById('xp-progress').style.width = `${this.xpProgress}%`;
        document.getElementById('next-rank').textContent = this.nextRank;
    },
    
    // Update tool information display
    updateToolInfo: function(tools) {
        if (tools) this.tools = tools;
        
        // Clear existing tool elements
        const toolsContainer = document.getElementById('tools-container');
        toolsContainer.innerHTML = '';
        
        // Add tool elements for each tool
        this.tools.forEach(tool => {
            const toolElement = document.createElement('div');
            toolElement.className = 'tool-item';
            
            // Determine durability class
            let durabilityClass = 'durability-good';
            if (tool.durability <= 25) {
                durabilityClass = 'durability-poor';
            } else if (tool.durability <= 50) {
                durabilityClass = 'durability-medium';
            }
            
            // Create tool HTML
            toolElement.innerHTML = `
                <div class="tool-icon">
                    <i class="${tool.icon || 'fas fa-wrench'}"></i>
                </div>
                <div class="tool-info">
                    <div class="tool-name">${tool.name}</div>
                    <div class="tool-durability">
                        <div class="durability-bar ${durabilityClass}" style="width: ${tool.durability}%"></div>
                    </div>
                </div>
            `;
            
            toolsContainer.appendChild(toolElement);
        });
    },
    
    // Show a notification
    showNotification: function(message, type = 'info') {
        // Create notification container if it doesn't exist
        let notifications = document.getElementById('notifications');
        if (notifications.classList.contains('hidden')) {
            notifications.classList.remove('hidden');
        }
        
        // Get icon based on type
        let icon = 'fas fa-info-circle';
        switch (type) {
            case 'success':
                icon = 'fas fa-check-circle';
                break;
            case 'error':
                icon = 'fas fa-times-circle';
                break;
            case 'warning':
                icon = 'fas fa-exclamation-triangle';
                break;
        }
        
        // Create notification element
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.innerHTML = `
            <div class="notification-icon">
                <i class="${icon}"></i>
            </div>
            <div class="notification-content">
                <div class="notification-message">${message}</div>
            </div>
        `;
        
        // Add to container
        notifications.appendChild(notification);
        
        // Remove after animation completes
        setTimeout(() => {
            notification.remove();
            
            // Hide notifications container if empty
            if (notifications.children.length === 0) {
                notifications.classList.add('hidden');
            }
        }, 5000);
    },
    
    // Send data back to the game
    sendData: function(action, data = {}) {
        fetch(`https://${GetParentResourceName()}/uiAction`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                action,
                ...data
            })
        });
    }
};

// Initialize the application when the DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    app.init();
}); 