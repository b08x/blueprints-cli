// Viewer Page JavaScript

class ViewerPage {
    constructor() {
        this.app = window.blueprintsApp;
        this.blueprintSearch = document.getElementById('blueprintSearch');
        this.blueprintList = document.getElementById('blueprintList');
        this.blueprintContent = document.getElementById('blueprintContent');
        this.emptyState = document.getElementById('emptyState');
        this.blueprintDetails = document.getElementById('blueprintDetails');
        this.blueprintTitle = document.getElementById('blueprintTitle');
        this.blueprintLastUpdated = document.getElementById('blueprintLastUpdated');
        this.metadataContent = document.getElementById('metadataContent');
        this.codeContent = document.getElementById('codeContent');
        this.copyCodeBtn = document.getElementById('copyCodeBtn');
        this.editBlueprintBtn = document.getElementById('editBlueprintBtn');
        this.regenerateBlueprintBtn = document.getElementById('regenerateBlueprintBtn');
        this.deleteBtn = document.getElementById('deleteBtn');
        this.newBlueprintBtn = document.getElementById('newBlueprintBtn');
        
        this.blueprints = [];
        this.currentBlueprint = null;
        this.searchQuery = '';
        
        this.init();
    }

    init() {
        this.setupEventHandlers();
        this.loadBlueprints();
        this.checkUrlForBlueprintId();
    }

    setupEventHandlers() {
        // Search functionality
        if (this.blueprintSearch) {
            const debouncedSearch = this.app.debounce((query) => {
                this.handleSearch(query);
            }, 300);

            this.blueprintSearch.addEventListener('input', (e) => {
                const query = e.target.value.trim();
                this.searchQuery = query;
                debouncedSearch(query);
            });
        }

        // Button handlers
        if (this.copyCodeBtn) {
            this.copyCodeBtn.addEventListener('click', () => {
                this.handleCopyCode();
            });
        }

        if (this.editBlueprintBtn) {
            this.editBlueprintBtn.addEventListener('click', () => {
                this.handleEdit();
            });
        }

        if (this.regenerateBlueprintBtn) {
            this.regenerateBlueprintBtn.addEventListener('click', () => {
                this.handleRegenerate();
            });
        }

        if (this.deleteBtn) {
            this.deleteBtn.addEventListener('click', () => {
                this.handleDelete();
            });
        }

        if (this.newBlueprintBtn) {
            this.newBlueprintBtn.addEventListener('click', () => {
                window.location.href = '/submission';
            });
        }
    }

    checkUrlForBlueprintId() {
        const urlParams = new URLSearchParams(window.location.search);
        const blueprintId = urlParams.get('id');
        
        if (blueprintId) {
            this.loadBlueprint(parseInt(blueprintId));
        }
    }

    async loadBlueprints() {
        if (!this.blueprintList) return;

        try {
            // Show loading state
            this.blueprintList.innerHTML = `
                <div class="loading">
                    <div class="spinner"></div>
                    Loading blueprints...
                </div>
            `;

            const blueprints = await this.app.searchBlueprints(this.searchQuery);
            this.blueprints = blueprints;
            this.renderBlueprintList(blueprints);
        } catch (error) {
            console.error('Failed to load blueprints:', error);
            this.showBlueprintListError();
        }
    }

    renderBlueprintList(blueprints) {
        if (!this.blueprintList) return;

        if (!blueprints || blueprints.length === 0) {
            this.showEmptyBlueprintList();
            return;
        }

        this.blueprintList.innerHTML = '';
        
        blueprints.forEach(blueprint => {
            const isActive = this.currentBlueprint && this.currentBlueprint.id === blueprint.id;
            const listItem = this.app.createBlueprintListItem(blueprint, isActive);
            
            // Override the default href behavior for SPA-like navigation
            listItem.addEventListener('click', (e) => {
                e.preventDefault();
                this.selectBlueprint(blueprint);
            });
            
            this.blueprintList.appendChild(listItem);
        });
    }

    showEmptyBlueprintList() {
        if (!this.blueprintList) return;

        const message = this.searchQuery 
            ? `No blueprints found for "${this.searchQuery}"`
            : 'No blueprints available';

        this.blueprintList.innerHTML = `
            <div style="padding: 2rem 1rem; text-align: center; color: var(--text-secondary);">
                <p>${message}</p>
                ${!this.searchQuery ? '<a href="/submission" class="btn btn-secondary" style="margin-top: 1rem;">Submit First Blueprint</a>' : ''}
            </div>
        `;
    }

    showBlueprintListError() {
        if (!this.blueprintList) return;

        this.blueprintList.innerHTML = `
            <div style="padding: 2rem 1rem; text-align: center; color: var(--text-secondary);">
                <p>Failed to load blueprints</p>
                <button onclick="window.location.reload()" class="btn btn-secondary" style="margin-top: 1rem;">
                    Retry
                </button>
            </div>
        `;
    }

    async handleSearch(query) {
        this.searchQuery = query;
        await this.loadBlueprints();
    }

    async selectBlueprint(blueprint) {
        // Update URL without page reload
        const newUrl = `/viewer?id=${blueprint.id}`;
        window.history.pushState({ blueprintId: blueprint.id }, '', newUrl);
        
        await this.loadBlueprint(blueprint.id);
    }

    async loadBlueprint(blueprintId) {
        if (!blueprintId) return;

        try {
            // Show loading state
            this.showBlueprintLoading();

            const blueprint = await this.app.getBlueprint(blueprintId);
            this.currentBlueprint = blueprint;
            this.renderBlueprintDetails(blueprint);
            this.updateActiveListItem(blueprintId);
        } catch (error) {
            console.error('Failed to load blueprint:', error);
            this.showBlueprintError(`Failed to load blueprint: ${error.message}`);
        }
    }

    showBlueprintLoading() {
        if (this.emptyState) this.emptyState.classList.add('hidden');
        if (this.blueprintDetails) this.blueprintDetails.classList.add('hidden');
        
        if (this.blueprintContent) {
            this.blueprintContent.innerHTML = `
                <div class="loading" style="padding: 4rem 2rem;">
                    <div class="spinner"></div>
                    Loading blueprint...
                </div>
            `;
        }
    }

    renderBlueprintDetails(blueprint) {
        if (!blueprint) return;

        // Hide empty state and show details
        if (this.emptyState) this.emptyState.classList.add('hidden');
        if (this.blueprintDetails) this.blueprintDetails.classList.remove('hidden');

        // Update title and metadata
        if (this.blueprintTitle) {
            this.blueprintTitle.textContent = blueprint.name || 'Untitled Blueprint';
        }

        if (this.blueprintLastUpdated) {
            const updatedText = blueprint.updated_at 
                ? `Last updated ${this.app.formatDate(blueprint.updated_at)}`
                : 'Recently created';
            this.blueprintLastUpdated.textContent = updatedText;
        }

        // Render metadata
        this.renderMetadata(blueprint);

        // Render code
        this.renderCode(blueprint);

        // Clear any error messages
        this.app.clearMessages();
    }

    renderMetadata(blueprint) {
        if (!this.metadataContent) return;

        this.metadataContent.innerHTML = '';

        // Description
        const descriptionRow = this.app.createMetadataRow(
            'Description', 
            blueprint.description || 'No description provided'
        );
        this.metadataContent.appendChild(descriptionRow);

        // Language
        if (blueprint.language) {
            const languageRow = this.app.createMetadataRow('Language', blueprint.language);
            this.metadataContent.appendChild(languageRow);
        }

        // Framework
        if (blueprint.framework) {
            const frameworkRow = this.app.createMetadataRow('Framework', blueprint.framework);
            this.metadataContent.appendChild(frameworkRow);
        }

        // Categories/Tags
        const tagsHtml = this.app.createTagsHtml(blueprint.categories);
        const tagsRow = this.app.createMetadataRow('Tags', tagsHtml);
        this.metadataContent.appendChild(tagsRow);

        // Created date
        if (blueprint.created_at) {
            const createdRow = this.app.createMetadataRow('Created', this.formatDate(blueprint.created_at));
            this.metadataContent.appendChild(createdRow);
        }
    }

    renderCode(blueprint) {
        if (!this.codeContent || !blueprint.code) return;

        const codeHtml = `<pre><code>${this.escapeHtml(blueprint.code)}</code></pre>`;
        this.codeContent.innerHTML = codeHtml;
    }

    updateActiveListItem(blueprintId) {
        // Remove active class from all items
        const allItems = this.blueprintList?.querySelectorAll('.blueprint-list-item');
        allItems?.forEach(item => item.classList.remove('active'));

        // Add active class to selected item
        const activeItem = this.blueprintList?.querySelector(`[data-blueprint-id="${blueprintId}"]`);
        if (activeItem) {
            activeItem.classList.add('active');
        }
    }

    showBlueprintError(message) {
        if (this.emptyState) this.emptyState.classList.add('hidden');
        if (this.blueprintDetails) this.blueprintDetails.classList.add('hidden');
        
        if (this.blueprintContent) {
            this.blueprintContent.innerHTML = `
                <div class="error" style="padding: 4rem 2rem; text-align: center;">
                    <p style="margin-bottom: 1rem;">${message}</p>
                    <button onclick="window.location.reload()" class="btn btn-secondary">
                        Try Again
                    </button>
                </div>
            `;
        }
    }

    handleCopyCode() {
        if (this.currentBlueprint && this.currentBlueprint.code) {
            this.app.copyToClipboard(this.currentBlueprint.code);
        }
    }

    handleEdit() {
        if (this.currentBlueprint) {
            // For now, redirect to submission page with data (could be enhanced)
            this.app.showMessage('Edit functionality coming soon!', 'info');
        }
    }

    handleRegenerate() {
        if (this.currentBlueprint) {
            // Redirect to generator with current blueprint as context
            const prompt = `Regenerate and improve: ${this.currentBlueprint.name}`;
            const encodedPrompt = encodeURIComponent(prompt);
            window.location.href = `/generator?prompt=${encodedPrompt}`;
        }
    }

    async handleDelete() {
        if (!this.currentBlueprint) return;

        const confirmed = confirm(`Are you sure you want to delete "${this.currentBlueprint.name}"? This action cannot be undone.`);
        if (!confirmed) return;

        try {
            // Show loading state
            this.app.showLoading(this.deleteBtn, true);

            // Note: Delete API endpoint would need to be implemented in the backend
            // For now, show a message
            this.app.showMessage('Delete functionality will be implemented in the backend.', 'info');
            
            // In a real implementation:
            // await this.app.deleteBlueprint(this.currentBlueprint.id);
            // this.app.showMessage('Blueprint deleted successfully!', 'success');
            // this.loadBlueprints();
            // this.showEmptyState();
            
        } catch (error) {
            console.error('Delete failed:', error);
            this.app.showMessage(`Delete failed: ${error.message}`, 'error');
        } finally {
            this.app.showLoading(this.deleteBtn, false);
        }
    }

    formatDate(dateString) {
        const date = new Date(dateString);
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Handle browser back/forward buttons
window.addEventListener('popstate', (event) => {
    if (event.state && event.state.blueprintId) {
        const viewerPage = window.viewerPageInstance;
        if (viewerPage) {
            viewerPage.loadBlueprint(event.state.blueprintId);
        }
    }
});

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.viewerPageInstance = new ViewerPage();
});