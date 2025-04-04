// Construction Item Placeholder Generator
document.addEventListener('DOMContentLoaded', function() {
    // List of all required item images
    const items = [
        'construction_helmet',
        'safety_vest',
        'work_gloves',
        'safety_boots',
        'hammer',
        'screwdriver_set',
        'power_drill',
        'measuring_tape',
        'wrench_set',
        'cement_bag',
        'lumber',
        'steel_beam',
        'brick_pack',
        'wire_bundle'
    ];

    // Create a placeholder canvas element
    const canvas = document.createElement('canvas');
    canvas.width = 128;
    canvas.height = 128;
    const ctx = canvas.getContext('2d');

    // Generate a placeholder for each item
    items.forEach(itemName => {
        // Clear canvas
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        
        // Set background
        ctx.fillStyle = '#2d3a4a';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        
        // Draw border
        ctx.strokeStyle = '#f0a30a';
        ctx.lineWidth = 4;
        ctx.strokeRect(4, 4, canvas.width - 8, canvas.height - 8);
        
        // Draw item name text
        ctx.fillStyle = '#ffffff';
        ctx.font = 'bold 14px Arial';
        ctx.textAlign = 'center';
        ctx.fillText(itemName.replace(/_/g, ' '), canvas.width / 2, canvas.height / 2);
        
        // Convert to data URL and create download link
        const dataURL = canvas.toDataURL('image/png');
        
        // Create a download link
        const link = document.createElement('a');
        link.href = dataURL;
        link.download = `${itemName}.png`;
        link.textContent = `Download ${itemName}.png`;
        link.style.display = 'block';
        link.style.margin = '5px';
        
        document.body.appendChild(link);
    });
    
    // Add instructions
    const instructions = document.createElement('div');
    instructions.innerHTML = `
        <h1>Construction Item Image Generator</h1>
        <p>Click on each link to download the placeholder image for that item.</p>
        <p>After downloading, place all images in the html/images directory.</p>
    `;
    document.body.prepend(instructions);
}); 