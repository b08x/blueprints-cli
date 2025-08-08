// Blueprints CLI - Main Application JavaScript

class BlueprintsApp {
    constructor() {
        this.apiBase = '/api';
        this.init();
    }

    init() {
        this.setupGlobalEventHandlers();
        this.initNavigation();
    }

    setupGlobalEventHandlers() {
        // Handle navigation active states
        this.updateActiveNavItem();
        
        // Handle responsive navigation
        this.setupMobileNavigation();
    }

    updateActiveNavItem() {
        const currentPath = window.location.pathname;
        const navItems = document.querySelectorAll('.nav-item');
        
        navItems.forEach(item => {
            item.classList.remove('active');
            const href = item.getAttribute('href');
            
            if (href === currentPath || (currentPath === '/' && href === '/')) {
                item.classList.add('active');
            }
        });
    }

    setupMobileNavigation() {
        const sidebar = document.querySelector('.sidebar');
        const menuToggle = document.getElementById('menuToggle');
        
        if (menuToggle && sidebar) {
            menuToggle.addEventListener('click', () => {
                sidebar.classList.toggle('hidden');
            });
        }
    }

    initNavigation() {
        // Set up navigation highlighting based on current page
        this.updateActiveNavItem();
        
        // Handle internal navigation
        document.addEventListener('click', (e) => {
            const link = e.target.closest('a[href^="/"]');
            if (link && !link.hasAttribute('data-external')) {
                // Let browser handle normal navigation for now
                // In future, could implement SPA routing here
            }
        });
    }

    // API Helper Methods
    async apiRequest(endpoint, options = {}) {
        const url = `${this.apiBase}${endpoint}`;
        const defaultOptions = {
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            }
        };

        const config = { ...defaultOptions, ...options };

        try {
            const response = await fetch(url, config);
            
            if (!response.ok) {
                const errorData = await response.json().catch(() => ({ error: 'Unknown error' }));
                throw new Error(errorData.error || `HTTP ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error('API Request failed:', error);
            throw error;
        }
    }

    async searchBlueprints(query = '') {
        const params = query ? `?query=${encodeURIComponent(query)}` : '';
        return this.apiRequest(`/blueprints${params}`);
    }

    async getBlueprint(id) {
        return this.apiRequest(`/blueprints/${id}`);
    }

    async createBlueprint(blueprintData) {
        return this.apiRequest('/blueprints', {
            method: 'POST',
            body: JSON.stringify(blueprintData)
        });
    }

    async generateCode(prompt, language = 'javascript', framework = 'react') {
        return this.apiRequest('/blueprints/generate', {
            method: 'POST',
            body: JSON.stringify({ prompt, language, framework })
        });
    }

    async generateMetadata(code) {
        return this.apiRequest('/blueprints/metadata', {
            method: 'POST',
            body: JSON.stringify({ code })
        });
    }

    // UI Helper Methods
    showMessage(message, type = 'info') {
        const messagesContainer = document.getElementById('messages');
        if (!messagesContainer) return;

        const messageElement = document.createElement('div');
        messageElement.className = type === 'error' ? 'error' : 'success';
        messageElement.textContent = message;

        messagesContainer.innerHTML = '';
        messagesContainer.appendChild(messageElement);

        // Auto-remove after 5 seconds
        setTimeout(() => {
            if (messageElement.parentNode) {
                messageElement.parentNode.removeChild(messageElement);
            }
        }, 5000);
    }

    clearMessages() {
        const messagesContainer = document.getElementById('messages');
        if (messagesContainer) {
            messagesContainer.innerHTML = '';
        }
    }

    showLoading(element, show = true) {
        if (!element) return;

        const spinner = element.querySelector('.spinner');
        const text = element.querySelector('[id$="Text"]');

        if (show) {
            if (spinner) spinner.classList.remove('hidden');
            if (text) text.style.opacity = '0.7';
            element.disabled = true;
        } else {
            if (spinner) spinner.classList.add('hidden');
            if (text) text.style.opacity = '1';
            element.disabled = false;
        }
    }

    formatDate(dateString) {
        const date = new Date(dateString);
        const now = new Date();
        const diffTime = Math.abs(now - date);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

        if (diffDays === 1) return 'Yesterday';
        if (diffDays < 7) return `${diffDays} days ago`;
        if (diffDays < 30) return `${Math.ceil(diffDays / 7)} weeks ago`;
        if (diffDays < 365) return `${Math.ceil(diffDays / 30)} months ago`;
        return `${Math.ceil(diffDays / 365)} years ago`;
    }

    copyToClipboard(text) {
        if (navigator.clipboard && window.isSecureContext) {
            return navigator.clipboard.writeText(text).then(() => {
                this.showMessage('Copied to clipboard!', 'success');
            }).catch(() => {
                this.fallbackCopyToClipboard(text);
            });
        } else {
            this.fallbackCopyToClipboard(text);
        }
    }

    fallbackCopyToClipboard(text) {
        const textArea = document.createElement('textarea');
        textArea.value = text;
        textArea.style.position = 'fixed';
        textArea.style.left = '-999999px';
        textArea.style.top = '-999999px';
        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();

        try {
            document.execCommand('copy');
            this.showMessage('Copied to clipboard!', 'success');
        } catch (error) {
            this.showMessage('Failed to copy to clipboard', 'error');
        } finally {
            document.body.removeChild(textArea);
        }
    }

    createBlueprintCard(blueprint) {
        const card = document.createElement('div');
        card.className = 'blueprint-card';
        card.setAttribute('data-blueprint-id', blueprint.id);
        
        const updatedText = blueprint.updated_at 
            ? `Last updated ${this.formatDate(blueprint.updated_at)}`
            : 'Recently added';

        card.innerHTML = `
            <div class="blueprint-card-image" style="background-image: url('data:image/svg+xml;base64,${btoa('<svg xmlns="http://www.w3.org/2000/svg" width="300" height="160" viewBox="0 0 300 160"><rect width="300" height="160" fill="#4a5568"/><text x="150" y="80" text-anchor="middle" fill="#cbd5e0" font-family="sans-serif" font-size="14">' + (blueprint.language || 'Code') + '</text></svg>')}')"></div>
            <div class="blueprint-card-content">
                <h3 class="blueprint-card-title">${blueprint.name || 'Untitled Blueprint'}</h3>
                <p class="blueprint-card-meta">${updatedText}</p>
            </div>
        `;

        card.addEventListener('click', () => {
            window.location.href = `/viewer?id=${blueprint.id}`;
        });

        return card;
    }

    createBlueprintListItem(blueprint, isActive = false) {
        const item = document.createElement('a');
        item.className = `blueprint-list-item ${isActive ? 'active' : ''}`;
        item.href = `/viewer?id=${blueprint.id}`;
        item.setAttribute('data-blueprint-id', blueprint.id);

        const updatedText = blueprint.updated_at 
            ? this.formatDate(blueprint.updated_at)
            : 'Recently added';

        item.innerHTML = `
            <div style="flex-shrink: 0; width: 2.5rem; height: 2.5rem; border-radius: 0.5rem; background: var(--surface-panels); display: flex; align-items: center; justify-content: center;">
                <svg style="width: 1.5rem; height: 1.5rem; color: var(--text-light-gray);" fill="currentColor" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
                    <path d="M181.66,146.34a8,8,0,0,1,0,11.32l-24,24a8,8,0,0,1-11.32-11.32L164.69,152l-18.35-18.34a8,8,0,0,1,11.32-11.32Zm-72-24a8,8,0,0,0-11.32,0l-24,24a8,8,0,0,0,0,11.32l24,24a8,8,0,0,0,11.32-11.32L91.31,152l18.35-18.34A8,8,0,0,0,109.66,122.34ZM216,88V216a16,16,0,0,1-16,16H56a16,16,0,0,1-16-16V40A16,16,0,0,1,56,24h96a8,8,0,0,1,5.66,2.34l56,56A8,8,0,0,1,216,88Zm-56-8h28.69L160,51.31Zm40,136V96H152a8,8,0,0,1-8-8V40H56V216H200Z"></path>
                </svg>
            </div>
            <div>
                <p style="font-weight: 500; color: var(--text-light-gray); margin: 0;">${blueprint.name || 'Untitled Blueprint'}</p>
                <p style="font-size: 0.875rem; color: var(--text-secondary); margin: 0;">Last updated ${updatedText}</p>
            </div>
        `;

        return item;
    }

    createMetadataRow(label, value) {
        const row = document.createElement('div');
        row.style.cssText = 'display: grid; grid-template-columns: 150px 1fr; gap: 1rem; padding: 1rem 0; border-bottom: 1px solid var(--border-color);';
        
        row.innerHTML = `
            <p style="color: var(--text-secondary); font-weight: 500; margin: 0;">${label}</p>
            <div style="color: var(--text-light-gray); margin: 0;">${value}</div>
        `;
        
        return row;
    }

    createTagsHtml(categories) {
        if (!categories || !Array.isArray(categories) || categories.length === 0) {
            return '<span class="tag">general</span>';
        }
        
        return categories.map(category => {
            const name = typeof category === 'string' ? category : category.name;
            return `<span class="tag">${name}</span>`;
        }).join('');
    }

    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
}

// Initialize the application
window.blueprintsApp = new BlueprintsApp();

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = BlueprintsApp;
}