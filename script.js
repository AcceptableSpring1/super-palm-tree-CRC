'strict'

window.addEventListener('load', () => {
  fetch('https://crc-func-btemhqemegc5ekd5.westus2-01.azurewebsites.net/api/visitorcounter', {
    method: 'POST'
  })
    .then(res => res.json())
    .then(data => {
      document.getElementById('visits').textContent = data.visits;
    })
    .catch(err => console.error('Visitor counter error:', err));
});
