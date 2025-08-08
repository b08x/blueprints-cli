// Index/Home Page JavaScript

class IndexPage {
    constructor() {
        this.app = window.blueprintsApp;
        this.searchInput = document.getElementById('searchInput');
        this.blueprintGrid = document.getElementById('blueprintGrid');
        this.currentSearchQuery = '';
        
        this.init();
    }

    init() {
        this.loadRecentBlueprints();
        this.setupSearchFunctionality();
    }

    async loadRecentBlueprints() {
        try {
            const blueprints = await this.app.searchBlueprints();
            this.renderBlueprints(blueprints);
        } catch (error) {
            console.error('Failed to load blueprints:', error);
            this.showError('Failed to load blueprints. Please try again.');
        }
    }

    setupSearchFunctionality() {
        if (!this.searchInput) return;

        const debouncedSearch = this.app.debounce(async (query) => {
            await this.performSearch(query);
        }, 300);

        this.searchInput.addEventListener('input', (e) => {
            const query = e.target.value.trim();
            this.currentSearchQuery = query;
            debouncedSearch(query);
        });

        this.searchInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                this.performSearch(this.searchInput.value.trim());
            }
        });
    }

    async performSearch(query) {
        if (!this.blueprintGrid) return;

        // Show loading state
        this.showLoading();

        try {
            const blueprints = await this.app.searchBlueprints(query);
            this.renderBlueprints(blueprints, query);
            
            // Update section title based on search
            const titleElement = document.querySelector('.card-title');
            if (titleElement) {
                titleElement.textContent = query 
                    ? `Search Results for "${query}"` 
                    : 'Recent Blueprints';
            }
        } catch (error) {
            console.error('Search failed:', error);
            this.showError('Search failed. Please try again.');
        }
    }

    renderBlueprints(blueprints, searchQuery = '') {
        if (!this.blueprintGrid) return;

        if (!blueprints || blueprints.length === 0) {
            this.showEmptyState(searchQuery);
            return;
        }

        // Clear existing content
        this.blueprintGrid.innerHTML = '';

        // Create blueprint cards
        blueprints.forEach(blueprint => {
            const card = this.app.createBlueprintCard(blueprint);
            this.blueprintGrid.appendChild(card);
        });
    }

    showEmptyState(searchQuery = '') {
        if (!this.blueprintGrid) return;

        const emptyMessage = searchQuery 
            ? `No blueprints found for "${searchQuery}"`
            : 'No blueprints available yet';

        const emptyStateHtml = `
            <div style="grid-column: 1 / -1; text-align: center; padding: 3rem 2rem; color: var(--text-secondary);">
                <svg style="width: 4rem; height: 4rem; margin: 0 auto 1rem; color: var(--text-secondary);" fill="currentColor" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
                    <path d="M229.66,218.34l-50.07-50.06a88.11,88.11,0,1,0-11.31,11.31l50.06,50.07a8,8,0,0,0,11.32-11.32ZM40,112a72,72,0,1,1,72,72A72.08,72.08,0,0,1,40,112Z"></path>
                </svg>
                <h3 style="font-size: 1.25rem; margin-bottom: 0.5rem; color: var(--text-light-gray);">${emptyMessage}</h3>
                <p style="margin-bottom: 1.5rem;">Try searching with different terms or create a new blueprint.</p>
                <div style="display: flex; gap: 1rem; justify-content: center;">
                    <a href="/generator" class="btn btn-secondary">Generate Blueprint</a>
                    <a href="/submission" class="btn btn-primary">Submit Blueprint</a>
                </div>
            </div>
        `;

        this.blueprintGrid.innerHTML = emptyStateHtml;
    }

    showLoading() {
        if (!this.blueprintGrid) return;

        this.blueprintGrid.innerHTML = `
            <div style="grid-column: 1 / -1;" class="loading">
                <div class="spinner"></div>
                ${this.currentSearchQuery ? 'Searching...' : 'Loading blueprints...'}
            </div>
        `;
    }

    showError(message) {
        if (!this.blueprintGrid) return;

        this.blueprintGrid.innerHTML = `
            <div style="grid-column: 1 / -1;" class="error">
                <p style="margin: 0;">${message}</p>
                <button onclick="window.location.reload()" class="btn btn-secondary" style="margin-top: 1rem;">
                    Try Again
                </button>
            </div>
        `;
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new IndexPage();
});