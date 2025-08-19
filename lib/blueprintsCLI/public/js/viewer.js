// Blueprints CLI Web UI - Viewer Page

document.addEventListener('DOMContentLoaded', function() {
    // Get blueprint ID from URL parameters
    const urlParams = new URLSearchParams(window.location.search);
    const blueprintId = urlParams.get('id');

    if (!blueprintId) {
        showError('No blueprint ID provided');
        return;
    }

    // Load blueprint details
    loadBlueprint(blueprintId);
    loadBlueprintsList();

    async function loadBlueprint(id) {
        try {
            showLoading();
            
            const blueprint = await app.getBlueprint(id);
            
            // Update page title and header
            updateTitle(blueprint.name || `Blueprint ${id}`);
            updateBlueprintDetails(blueprint);
            
        } catch (error) {
            console.error('Failed to load blueprint:', error);
            showError(`Failed to load blueprint: ${error.message}`);
        }
    }

    async function loadBlueprintsList() {
        try {
            const blueprints = await app.getBlueprints();
            updateSidebar(blueprints);
        } catch (error) {
            console.error('Failed to load blueprints list:', error);
        }
    }

    function updateTitle(name) {
        document.title = `${name} - Blueprints CLI`;
        const titleElement = document.querySelector('h2');
        if (titleElement) {
            titleElement.textContent = name;
        }
    }

    function updateBlueprintDetails(blueprint) {
        // Update metadata section
        updateMetadata(blueprint);
        
        // Update code section
        updateCode(blueprint);
        
        // Update last updated
        const updatedElement = document.querySelector('h2 + p');
        if (updatedElement && blueprint.updated_at) {
            const date = new Date(blueprint.updated_at);
            updatedElement.textContent = `Last updated ${formatDate(date)}`;
        }
    }

    function updateMetadata(blueprint) {
        const metadataRows = [
            { key: 'Description', value: blueprint.description || 'No description available' },
            { key: 'Language', value: blueprint.language || 'Unknown' },
            { key: 'File Type', value: blueprint.file_type || 'Unknown' },
            { key: 'Blueprint Type', value: blueprint.blueprint_type || 'code' }
        ];

        const firstMetadataRow = document.querySelector('.metadata-row');
        if (firstMetadataRow && firstMetadataRow.parentElement) {
            const metadataSection = firstMetadataRow.parentElement;
            metadataSection.innerHTML = metadataRows.map(row => `
                <div class="metadata-row">
                    <p class="text-[var(--text-secondary)] font-medium">${row.key}</p>
                    <p class="text-[var(--text-light-gray)]">${escapeHtml(row.value)}</p>
                </div>
            `).join('');
        }
    }

    function updateCode(blueprint) {
        const codeBlock = document.querySelector('.code-block pre code');
        if (codeBlock && blueprint.code) {
            codeBlock.textContent = blueprint.code;
        }
    }

    function updateSidebar(blueprints) {
        const nav = document.querySelector('nav');
        if (!nav || !blueprints.length) return;

        const currentId = new URLSearchParams(window.location.search).get('id');
        
        nav.innerHTML = blueprints.map(blueprint => {
            const isActive = blueprint.id.toString() === currentId;
            return `
                <a class="blueprint-list-item ${isActive ? 'active' : ''}" 
                   href="/viewer?id=${blueprint.id}">
                    <div class="flex-shrink-0 size-10 rounded-lg bg-[var(--surface-panels)] flex items-center justify-center">
                        <svg class="h-6 w-6 text-[var(--text-light-gray)]" fill="currentColor" viewBox="0 0 256 256">
                            <path d="M181.66,146.34a8,8,0,0,1,0,11.32l-24,24a8,8,0,0,1-11.32-11.32L164.69,152l-18.35-18.34a8,8,0,0,1,11.32-11.32Zm-72-24a8,8,0,0,0-11.32,0l-24,24a8,8,0,0,0,0,11.32l24,24a8,8,0,0,0,11.32-11.32L91.31,152l18.35-18.34A8,8,0,0,0,109.66,122.34ZM216,88V216a16,16,0,0,1-16,16H56a16,16,0,0,1-16-16V40A16,16,0,0,1,56,24h96a8,8,0,0,1,5.66,2.34l56,56A8,8,0,0,1,216,88Zm-56-8h28.69L160,51.31Zm40,136V96H152a8,8,0,0,1-8-8V40H56V216H200Z"/>
                        </svg>
                    </div>
                    <div>
                        <p class="font-medium text-[var(--text-light-gray)]">${escapeHtml(blueprint.name || `Blueprint ${blueprint.id}`)}</p>
                        <p class="text-sm text-[var(--text-secondary)]">Last updated ${formatDate(new Date(blueprint.updated_at))}</p>
                    </div>
                </a>
            `;
        }).join('');
    }

    function showLoading() {
        const mainContent = document.querySelector('main .flex-1 .max-w-4xl');
        if (mainContent) {
            mainContent.innerHTML = `
                <div class="flex items-center justify-center py-16">
                    <div class="text-center">
                        <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-[var(--secondary-accent)] mx-auto mb-4"></div>
                        <p class="text-[var(--text-secondary)]">Loading blueprint...</p>
                    </div>
                </div>
            `;
        }
    }

    function showError(message) {
        const mainContent = document.querySelector('main .flex-1 .max-w-4xl');
        if (mainContent) {
            mainContent.innerHTML = `
                <div class="text-center py-16">
                    <div class="mb-4">
                        <svg class="mx-auto h-12 w-12 text-[var(--primary-accent)]" fill="currentColor" viewBox="0 0 256 256">
                            <path d="M165.66,101.66,139.31,128l26.35,26.34a8,8,0,0,1-11.32,11.32L128,139.31l-26.34,26.35a8,8,0,0,1-11.32-11.32L116.69,128,90.34,101.66a8,8,0,0,1,11.32-11.32L128,116.69l26.34-26.35a8,8,0,0,1,11.32,11.32ZM232,128A104,104,0,1,1,128,24,104.11,104.11,0,0,1,232,128Zm-16,0a88,88,0,1,0-88,88A88.1,88.1,0,0,0,216,128Z"/>
                        </svg>
                    </div>
                    <h2 class="text-xl font-semibold text-white mb-2">Error Loading Blueprint</h2>
                    <p class="text-[var(--text-secondary)] mb-4">${escapeHtml(message)}</p>
                    <a href="/" class="inline-block px-4 py-2 bg-[var(--primary-accent)] text-white rounded-lg hover:bg-opacity-80 transition-colors">
                        Back to Home
                    </a>
                </div>
            `;
        }
    }

    function formatDate(date) {
        const now = new Date();
        const diffTime = Math.abs(now - date);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

        if (diffDays === 1) return '1 day ago';
        if (diffDays < 7) return `${diffDays} days ago`;
        if (diffDays < 14) return '1 week ago';
        if (diffDays < 30) return `${Math.ceil(diffDays / 7)} weeks ago`;
        if (diffDays < 60) return '1 month ago';
        
        return date.toLocaleDateString();
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // Setup search functionality in sidebar
    const searchInput = document.querySelector('.search-input');
    if (searchInput) {
        const debouncedSearch = app.debounce(async function(query) {
            try {
                const blueprints = await app.getBlueprints(query);
                updateSidebar(blueprints);
            } catch (error) {
                console.error('Search failed:', error);
            }
        }, 300);

        searchInput.addEventListener('input', function() {
            const query = this.value.trim();
            debouncedSearch(query);
        });
    }
});