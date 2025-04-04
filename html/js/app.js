// Vein Construction UI
const VeinUI = {
    // Cache DOM elements
    elements: {
        menuContainer: document.getElementById('menu-container'),
        menuTitle: document.getElementById('menu-title'),
        menuContent: document.getElementById('menu-content'),
        closeMenuBtn: document.getElementById('close-menu'),
        backButton: document.getElementById('back-button'),
        notificationContainer: document.getElementById('notification-container')
    },

    // Store menu history for back button functionality
    menuHistory: [],
    currentMenu: null,

    // Initialize the UI
    init: function() {
        this.setupEventListeners();
        // Listen for messages from the game client
        window.addEventListener('message', this.handleMessage.bind(this));
    },

    // Set up event listeners
    setupEventListeners: function() {
        // Close menu button
        this.elements.closeMenuBtn.addEventListener('click', () => {
            this.closeMenu();
            fetch(`https://${GetParentResourceName()}/closeMenu`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            });
        });

        // Back button
        this.elements.backButton.addEventListener('click', () => {
            this.goBack();
        });

        // Close on ESC key
        document.addEventListener('keyup', (event) => {
            if (event.key === 'Escape') {
                this.closeMenu();
                fetch(`https://${GetParentResourceName()}/closeMenu`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({})
                });
            }
        });
    },

    // Handle messages from the game client
    handleMessage: function(event) {
        const data = event.data;

        if (!data.action) return;

        switch (data.action) {
            case 'showMenu':
                this.showMenu(data.id, data.title, data.options, data.parent);
                break;
            case 'closeMenu':
                this.closeMenu();
                break;
            case 'showNotification':
                this.showNotification(data.title, data.message, data.type, data.icon);
                break;
        }
    },

    // Show a menu
    showMenu: function(id, title, options, parent) {
        // Update menu title
        this.elements.menuTitle.textContent = title;

        // If parent menu is specified, add to history
        if (parent && parent !== this.currentMenu) {
            if (this.currentMenu) {
                this.menuHistory.push(this.currentMenu);
            }
            this.elements.backButton.classList.remove('hidden');
        } else if (!parent) {
            this.menuHistory = [];
            this.elements.backButton.classList.add('hidden');
        }

        this.currentMenu = id;

        // Clear existing menu content
        this.elements.menuContent.innerHTML = '';

        // Add menu options
        if (options && options.length > 0) {
            options.forEach((option, index) => {
                const optionElement = document.createElement('div');
                optionElement.className = 'menu-option fade-in';
                optionElement.style.animationDelay = `${index * 0.05}s`;

                // Create option HTML structure
                optionElement.innerHTML = `
                    <div class="option-icon">
                        <i class="${option.icon || 'fas fa-circle'}"></i>
                    </div>
                    <div class="option-text">
                        <div class="option-title">${option.title || 'Option'}</div>
                        <div class="option-description">${option.description || ''}</div>
                        ${option.progress ? `
                            <div class="progress-container">
                                <div class="progress-bar" style="width: ${option.progress}%"></div>
                            </div>
                        ` : ''}
                    </div>
                `;

                // Add click event listener
                if (option.onSelect !== false) {
                    optionElement.addEventListener('click', () => {
                        // Send selection to game client
                        fetch(`https://${GetParentResourceName()}/menuSelect`, {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json'
                            },
                            body: JSON.stringify({
                                menuId: id,
                                optionIndex: index,
                                optionId: option.id || null
                            })
                        });
                    });
                }

                this.elements.menuContent.appendChild(optionElement);
            });
        } else {
            // Show empty menu message
            const emptyElement = document.createElement('div');
            emptyElement.className = 'menu-option fade-in';
            emptyElement.innerHTML = `
                <div class="option-icon">
                    <i class="fas fa-info-circle"></i>
                </div>
                <div class="option-text">
                    <div class="option-title">No options available</div>
                    <div class="option-description">There are no options to display at this time.</div>
                </div>
            `;
            this.elements.menuContent.appendChild(emptyElement);
        }

        // Show the menu
        this.elements.menuContainer.classList.remove('hidden');
        setTimeout(() => {
            this.elements.menuContainer.classList.add('visible');
        }, 10);
    },

    // Close the menu
    closeMenu: function() {
        this.elements.menuContainer.classList.remove('visible');
        setTimeout(() => {
            this.elements.menuContainer.classList.add('hidden');
            this.currentMenu = null;
            this.menuHistory = [];
        }, 300);
    },

    // Go back to previous menu
    goBack: function() {
        if (this.menuHistory.length > 0) {
            const previousMenu = this.menuHistory.pop();
            
            fetch(`https://${GetParentResourceName()}/goBack`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    menuId: previousMenu
                })
            });

            if (this.menuHistory.length === 0) {
                this.elements.backButton.classList.add('hidden');
            }
        } else {
            this.closeMenu();
        }
    },

    // Show a notification
    showNotification: function(title, message, type = 'info', icon = null) {
        // Determine icon based on type
        let iconClass = 'fas fa-info-circle';
        if (icon) {
            iconClass = icon;
        } else {
            switch (type) {
                case 'success':
                    iconClass = 'fas fa-check-circle';
                    break;
                case 'error':
                    iconClass = 'fas fa-exclamation-circle';
                    break;
                case 'warning':
                    iconClass = 'fas fa-exclamation-triangle';
                    break;
            }
        }

        // Create notification element
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.innerHTML = `
            <div class="notification-icon">
                <i class="${iconClass}"></i>
            </div>
            <div class="notification-content">
                <div class="notification-title">${title}</div>
                <div class="notification-message">${message}</div>
            </div>
        `;

        // Add to DOM
        this.elements.notificationContainer.appendChild(notification);

        // Animate in
        setTimeout(() => {
            notification.classList.add('showing');
        }, 10);

        // Auto remove after 5 seconds
        setTimeout(() => {
            notification.classList.remove('showing');
            setTimeout(() => {
                notification.remove();
            }, 300);
        }, 5000);
    }
};

// Initialize the UI when the DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    VeinUI.init();
}); 