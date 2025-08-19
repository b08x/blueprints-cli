// Blueprints CLI Web UI - Main Application
class BlueprintsApp {
    constructor() {
        // Support different environments
        this.apiUrl = this.getApiUrl();
    }

    getApiUrl() {
        // Check if we're in a containerized environment
        if (window.location.hostname === 'localhost' && window.location.port === '8080') {
            // Development environment - frontend on port 8080, backend on port 3000
            return 'http://localhost:3000/api';
        } else if (window.location.hostname.includes('docker') || process?.env?.NODE_ENV === 'production') {
            // Production environment - use backend service name
            return 'http://backend:3000/api';
        } else {
            // Default to relative paths for standalone development
            return '/api';
        }
    }

    // Utility method for making API requests
    async request(url, options = {}) {
        const config = {
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            },
            ...options
        };

        try {
            const response = await fetch(this.apiUrl + url, config);
            
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            return await response.json();
        } catch (error) {
            console.error('API request failed:', error);
            throw error;
        }
    }

    // Get blueprints with optional search query
    async getBlueprints(query = '') {
        const url = query ? `/blueprints?query=${encodeURIComponent(query)}` : '/blueprints';
        const response = await this.request(url);
        // The API returns {blueprints: [...], total: N, query: "..."} 
        // but the frontend expects just the array of blueprints
        return response.blueprints || response;
    }

    // Get a single blueprint by ID
    async getBlueprint(id) {
        return this.request(`/blueprints/${id}`);
    }

    // Create a new blueprint
    async createBlueprint(blueprintData) {
        return this.request('/blueprints', {
            method: 'POST',
            body: JSON.stringify(blueprintData)
        });
    }

    // Generate code from prompt
    async generateCode(prompt, language = 'javascript', framework = '') {
        return this.request('/blueprints/generate', {
            method: 'POST',
            body: JSON.stringify({ prompt, language, framework })
        });
    }

    // Generate metadata from code
    async generateMetadata(code) {
        return this.request('/blueprints/metadata', {
            method: 'POST',
            body: JSON.stringify({ code })
        });
    }

    // Utility method to show loading state
    showLoading(element, message = 'Loading...') {
        element.innerHTML = `
            <div class="text-center text-[var(--text-secondary)] py-8">
                <div class="loading mx-auto mb-2"></div>
                <div>${message}</div>
            </div>
        `;
    }

    // Utility method to show error state
    showError(element, message = 'An error occurred') {
        element.innerHTML = `
            <div class="error-message">
                <strong>Error:</strong> ${message}
            </div>
        `;
    }

    // Create blueprint card HTML
    createBlueprintCard(blueprint) {
        return `
            <div class="blueprint-card" data-id="${blueprint.id || ''}">
                <div class="blueprint-content">
                    <h3 class="blueprint-title">${blueprint.name || 'Untitled Blueprint'}</h3>
                    <p class="blueprint-meta">
                        ${blueprint.language ? blueprint.language + ' • ' : ''}
                        ${blueprint.updated_at ? 'Updated ' + this.formatDate(blueprint.updated_at) : 'Recently created'}
                    </p>
                    ${blueprint.description ? `<p class="text-sm mt-2 text-[var(--text-secondary)]">${blueprint.description.substring(0, 100)}${blueprint.description.length > 100 ? '...' : ''}</p>` : ''}
                </div>
            </div>
        `;
    }

    // Format date for display
    formatDate(dateString) {
        const date = new Date(dateString);
        const now = new Date();
        const diffTime = Math.abs(now - date);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

        if (diffDays === 1) return 'Yesterday';
        if (diffDays < 7) return `${diffDays} days ago`;
        if (diffDays < 30) return `${Math.ceil(diffDays / 7)} weeks ago`;
        return date.toLocaleDateString();
    }
}

// Initialize the app
window.app = new BlueprintsApp();

// Test API connection on page load
document.addEventListener('DOMContentLoaded', function() {
    console.log('BlueprintsApp initialized');
    console.log('API URL:', window.app.apiUrl);
});