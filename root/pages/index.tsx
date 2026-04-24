const Redirect = () => {
  if (typeof window !== 'undefined') {
    window.location.replace('https://frontend-rose-pi-gy8jdat7ef.vercel.app');
  }
  return null;
};

export default Redirect;
