// Blueprints CLI Web UI - Index Page
document.addEventListener('DOMContentLoaded', function() {
    const searchInput = document.getElementById('searchInput');
    const blueprintsGrid = document.getElementById('blueprintsGrid');
    
    // Load initial blueprints
    loadBlueprints();
    
    // Set up search functionality with debouncing
    if (searchInput) {
        let searchTimeout;
        searchInput.addEventListener('input', function() {
            clearTimeout(searchTimeout);
            searchTimeout = setTimeout(() => {
                const query = this.value.trim();
                loadBlueprints(query);
            }, 300);
        });
    }

    async function loadBlueprints(query = '') {
        if (!blueprintsGrid) return;
        
        try {
            // Show loading state
            window.app.showLoading(blueprintsGrid, 'Loading blueprints...');
            
            // Fetch blueprints from API
            const blueprints = await window.app.getBlueprints(query);
            
            // Clear and populate grid
            if (blueprints && blueprints.length > 0) {
                blueprintsGrid.innerHTML = blueprints.map(blueprint => 
                    window.app.createBlueprintCard(blueprint)
                ).join('');
                
                // Add click handlers to blueprint cards
                blueprintsGrid.querySelectorAll('.blueprint-card').forEach(card => {
                    card.addEventListener('click', function() {
                        const blueprintId = this.dataset.id;
                        if (blueprintId) {
                            // Navigate to viewer page with blueprint ID
                            window.location.href = `viewer.html?id=${blueprintId}`;
                        }
                    });
                });
            } else {
                blueprintsGrid.innerHTML = `
                    <div class="col-span-full text-center py-8">
                        <div class="text-[var(--text-secondary)]">
                            ${query ? `No blueprints found for "${query}"` : 'No blueprints available'}
                        </div>
                    </div>
                `;
            }
        } catch (error) {
            console.error('Failed to load blueprints:', error);
            window.app.showError(blueprintsGrid, 'Failed to load blueprints. Please try again.');
        }
    }

    // Add some demo functionality
    const demoButton = document.createElement('button');
    demoButton.textContent = 'Test API Connection';
    demoButton.className = 'btn-primary mt-4';
    demoButton.addEventListener('click', async function() {
        try {
            const response = await fetch(window.app.apiUrl.replace('/api', '/health'));
            const data = await response.json();
            alert(`API Connection: ${data.status}\nMessage: ${data.message}`);
        } catch (error) {
            alert(`API Connection Failed: ${error.message}`);
        }
    });
    
    // Add demo button to sidebar if it exists
    const sidebar = document.querySelector('aside');
    if (sidebar) {
        sidebar.appendChild(demoButton);
    }
});