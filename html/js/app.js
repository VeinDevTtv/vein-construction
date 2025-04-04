// Vein Construction UI
const VeinUI = {
    // Cache DOM elements
    elements: {
        menuContainer: document.getElementById('menu-container'),
        menuTitle: document.getElementById('menu-title'),
        menuContent: document.getElementById('menu-content'),
        closeMenuBtn: document.getElementById('close-menu'),
        backButton: document.getElementById('back-button'),
        notificationContainer: document.getElementById('notification-container'),
        statusDisplay: document.getElementById('status-display'),
        footerInfo: document.getElementById('footer-info'),
        progressOverlay: document.getElementById('progress-overlay'),
        progressBar: document.getElementById('progress-bar'),
        progressLabel: document.getElementById('progress-label'),
        // Status elements
        statusDuty: document.getElementById('status-duty'),
        statusRank: document.getElementById('status-rank'),
        statusXP: document.getElementById('status-xp'),
        statusSite: document.getElementById('status-site'),
        statusTask: document.getElementById('status-task'),
        statusProgressBar: document.getElementById('status-progress-bar')
    },

    // Store menu history for back button functionality
    menuHistory: [],
    currentMenu: null,
    
    // Store job status
    jobStatus: {
        onDuty: false,
        rank: "Apprentice",
        xp: 0,
        nextRankXP: 100,
        site: "None",
        task: "None",
        taskProgress: 0,
        tools: {},
        safetyGear: {
            hasHelmet: false,
            hasVest: false,
            hasGloves: false
        }
    },

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
                if (this.elements.progressOverlay.classList.contains('visible')) {
                    // Don't close if progress overlay is active
                    return;
                }
                
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
                this.showMenu(data.id, data.title, data.options, data.parent, data.footerInfo);
                break;
            case 'closeMenu':
                this.closeMenu();
                break;
            case 'showNotification':
                this.showNotification(data.title, data.message, data.type, data.icon);
                break;
            case 'updateJobStatus':
                this.updateJobStatus(data.status);
                break;
            case 'toggleStatusDisplay':
                this.toggleStatusDisplay(data.show);
                break;
            case 'showProgress':
                this.showProgressBar(data.label, data.duration);
                break;
            case 'updateProgress':
                this.updateProgressBar(data.progress);
                break;
            case 'hideProgress':
                this.hideProgressBar();
                break;
        }
    },

    // Show a menu
    showMenu: function(id, title, options, parent, footerInfo) {
        // Update menu title
        this.elements.menuTitle.textContent = title;

        // Update footer info if provided
        if (footerInfo) {
            this.elements.footerInfo.textContent = footerInfo;
            this.elements.footerInfo.style.display = 'block';
        } else {
            this.elements.footerInfo.style.display = 'none';
        }

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

        // Process sections if they exist
        if (options && options.sections) {
            options.sections.forEach(section => {
                // Create section container
                const sectionElement = document.createElement('div');
                sectionElement.className = 'menu-section fade-in';
                
                // Add section title if provided
                if (section.title) {
                    const sectionTitle = document.createElement('div');
                    sectionTitle.className = 'section-title';
                    sectionTitle.textContent = section.title;
                    sectionElement.appendChild(sectionTitle);
                }
                
                // Add section items
                if (section.items && section.items.length > 0) {
                    section.items.forEach((option, index) => {
                        const optionElement = this.createOptionElement(option, index, id);
                        sectionElement.appendChild(optionElement);
                    });
                }
                
                this.elements.menuContent.appendChild(sectionElement);
            });
        } 
        // If no sections, process options directly
        else if (options && options.length > 0) {
            options.forEach((option, index) => {
                const optionElement = this.createOptionElement(option, index, id);
                this.elements.menuContent.appendChild(optionElement);
            });
        } 
        // Show empty menu message if no options or sections
        else {
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

    // Create an option element
    createOptionElement: function(option, index, menuId) {
        const optionElement = document.createElement('div');
        optionElement.className = 'menu-option fade-in';
        optionElement.style.animationDelay = `${index * 0.05}s`;

        // Add additional classes
        if (option.disabled) {
            optionElement.classList.add('disabled');
        }
        if (option.highlight) {
            optionElement.classList.add('highlight');
        }
        if (option.pulse) {
            optionElement.classList.add('pulse');
        }

        // Create option HTML structure
        let optionHTML = `
            <div class="option-icon">
                <i class="${option.icon || 'fas fa-circle'}"></i>
            </div>
            <div class="option-text">
                <div class="option-title">${option.title || 'Option'}`;
        
        // Add badge if present
        if (option.badge) {
            optionHTML += `<span class="badge badge-${option.badge.type}">${option.badge.text}</span>`;
        }
        
        optionHTML += `</div>
                <div class="option-description">${option.description || ''}</div>`;
        
        // Add progress bar if needed
        if (option.progress !== undefined) {
            optionHTML += `
                <div class="progress-container">
                    <div class="progress-bar" style="width: ${option.progress}%"></div>
                </div>
            `;
        }
        
        optionHTML += `</div>`;
        
        optionElement.innerHTML = optionHTML;

        // Add click event listener
        if (!option.disabled && option.onSelect !== false) {
            optionElement.addEventListener('click', () => {
                // Add visual feedback
                optionElement.classList.add('active');
                setTimeout(() => optionElement.classList.remove('active'), 200);
                
                // Send selection to game client
                fetch(`https://${GetParentResourceName()}/menuSelect`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        menuId: menuId,
                        optionIndex: index,
                        optionId: option.id || null
                    })
                });
            });
        }

        return optionElement;
    },

    // Display a job level card
    createJobLevelCard: function(rank, xp, nextRankXP) {
        const element = document.createElement('div');
        element.className = 'job-level-display fade-in';
        
        // Calculate progress percentage
        let progressPercentage = 0;
        if (nextRankXP > 0) {
            progressPercentage = Math.min(100, (xp / nextRankXP) * 100);
        } else {
            progressPercentage = 100; // Max rank
        }
        
        element.innerHTML = `
            <div class="job-level-title">
                <span>Current Rank</span>
                <span class="job-level-badge">${rank}</span>
            </div>
            <div class="job-level-progress">
                <div class="progress-container">
                    <div class="progress-bar" style="width: ${progressPercentage}%"></div>
                </div>
            </div>
            <div class="job-level-stats">
                <div class="job-stat-item">
                    <div class="job-stat-value">${xp}</div>
                    <div class="job-stat-label">Current XP</div>
                </div>
                <div class="job-stat-item">
                    <div class="job-stat-value">${nextRankXP - xp}</div>
                    <div class="job-stat-label">XP Until Promotion</div>
                </div>
            </div>
        `;
        
        return element;
    },

    // Create an item grid
    createItemGrid: function(items, type) {
        const element = document.createElement('div');
        element.className = 'item-grid';
        
        items.forEach(item => {
            const itemElement = document.createElement('div');
            itemElement.className = 'item-card';
            itemElement.innerHTML = `
                <div class="item-icon">
                    <i class="${item.icon || 'fas fa-box'}"></i>
                </div>
                <div class="item-name">${item.name}</div>
                <div class="item-price">$${item.price}</div>
            `;
            
            // Add click event for purchasing
            itemElement.addEventListener('click', () => {
                fetch(`https://${GetParentResourceName()}/buyItem`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        item: item.id,
                        type: type
                    })
                });
            });
            
            element.appendChild(itemElement);
        });
        
        return element;
    },

    // Create a task card
    createTaskCard: function(task) {
        const element = document.createElement('div');
        element.className = 'task-card fade-in';
        
        let statusClass = 'available';
        if (task.isActive) {
            statusClass = 'active';
        } else if (task.isCompleted) {
            statusClass = 'completed';
        }
        
        element.innerHTML = `
            <div class="task-header">
                <div class="task-title">
                    <i class="${task.icon || 'fas fa-tasks'}"></i>
                    ${task.title}
                </div>
                <div class="task-status ${statusClass}">
                    ${task.isActive ? 'Active' : task.isCompleted ? 'Completed' : 'Available'}
                </div>
            </div>
            <div class="task-description">${task.description}</div>
            ${task.requirements ? `
                <div class="task-requirements">
                    <div class="task-requirement-title">Requirements:</div>
                    ${task.requirements.map(req => `
                        <div class="task-requirement-item">
                            <i class="${req.hasItem ? 'fas fa-check' : 'fas fa-times'}"></i>
                            <div class="task-requirement-name">${req.name}</div>
                        </div>
                    `).join('')}
                </div>
            ` : ''}
        `;
        
        if (task.canStart) {
            element.addEventListener('click', () => {
                fetch(`https://${GetParentResourceName()}/startTask`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        taskId: task.id
                    })
                });
            });
        }
        
        return element;
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
            <div class="notification-close"><i class="fas fa-times"></i></div>
        `;

        // Add close button functionality
        const closeBtn = notification.querySelector('.notification-close');
        closeBtn.addEventListener('click', () => {
            notification.classList.remove('showing');
            setTimeout(() => {
                notification.remove();
            }, 300);
        });

        // Add to DOM
        this.elements.notificationContainer.appendChild(notification);

        // Animate in
        setTimeout(() => {
            notification.classList.add('showing');
        }, 10);

        // Auto remove after 5 seconds
        setTimeout(() => {
            if (notification.parentNode) {
                notification.classList.remove('showing');
                setTimeout(() => {
                    if (notification.parentNode) {
                        notification.remove();
                    }
                }, 300);
            }
        }, 5000);
    },

    // Update job status display
    updateJobStatus: function(status) {
        if (!status) return;
        
        // Update the cached status
        Object.assign(this.jobStatus, status);
        
        // Update DOM elements
        if (status.onDuty !== undefined) {
            this.elements.statusDuty.textContent = status.onDuty ? 'On Duty' : 'Off Duty';
            this.elements.statusDuty.className = status.onDuty ? 'status-value status-active' : 'status-value';
        }
        
        if (status.rank) {
            this.elements.statusRank.textContent = status.rank;
        }
        
        if (status.xp !== undefined) {
            this.elements.statusXP.textContent = `${status.xp} XP`;
        }
        
        if (status.site) {
            this.elements.statusSite.textContent = status.site;
        }
        
        if (status.task) {
            this.elements.statusTask.textContent = status.task;
        }
        
        if (status.taskProgress !== undefined) {
            this.elements.statusProgressBar.style.width = `${status.taskProgress}%`;
        }
    },

    // Toggle the status display
    toggleStatusDisplay: function(show) {
        if (show) {
            this.elements.statusDisplay.classList.remove('hidden');
            this.elements.statusDisplay.classList.add('visible');
        } else {
            this.elements.statusDisplay.classList.remove('visible');
            this.elements.statusDisplay.classList.add('hidden');
        }
    },

    // Show progress bar
    showProgressBar: function(label, duration) {
        this.elements.progressLabel.textContent = label;
        this.elements.progressBar.style.width = '0%';
        this.elements.progressOverlay.classList.remove('hidden');
        this.elements.progressOverlay.classList.add('visible');
        
        let startTime = Date.now();
        let intervalId = setInterval(() => {
            let elapsed = Date.now() - startTime;
            let progress = Math.min(100, (elapsed / duration) * 100);
            this.elements.progressBar.style.width = `${progress}%`;
            
            if (progress >= 100) {
                clearInterval(intervalId);
                setTimeout(() => {
                    this.hideProgressBar();
                }, 500);
            }
        }, 50);
    },

    // Update progress bar directly
    updateProgressBar: function(progress) {
        this.elements.progressBar.style.width = `${progress}%`;
    },

    // Hide progress bar
    hideProgressBar: function() {
        this.elements.progressOverlay.classList.remove('visible');
        setTimeout(() => {
            this.elements.progressOverlay.classList.add('hidden');
        }, 300);
    }
};

// Initialize the UI when the DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    VeinUI.init();
}); 