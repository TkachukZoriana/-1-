(function () {
  const EMAILJS_PUBLIC_KEY = 't9JR0BLFCVNBsDGec';
  const EMAILJS_SERVICE_ID = 'service_hnixm61';
  const EMAILJS_TEMPLATE_ID = 'template_al0kvd9';
  const EMAILJS_AUTO_REPLY_TEMPLATE_ID = 'template_rwzs9vm';

  const menuToggle = document.getElementById('menuToggle');
  const mainNav = document.getElementById('mainNav');

  if (menuToggle && mainNav) {
    menuToggle.addEventListener('click', () => {
      mainNav.classList.toggle('open');
    });
  }

  if (window.jQuery) {
    $('.tab-btn').on('click', function () {
      const tabId = $(this).data('tab');
      $('.tab-btn').removeClass('active');
      $(this).addClass('active');
      $('.tab-panel').removeClass('active').hide();
      $('#' + tabId).addClass('active').fadeIn(220);
    });

    $('.faq-question').on('click', function () {
      const answer = $(this).next('.faq-answer');
      $('.faq-answer').not(answer).slideUp(200);
      answer.stop(true, true).slideToggle(220);
    });
  }

  const bookingForm = document.getElementById('bookingForm');

  if (bookingForm) {
    const nameInput = document.getElementById('name');
    const surnameInput = document.getElementById('surname');
    const phoneInput = document.getElementById('phone');
    const emailInput = document.getElementById('email');
    const guestsInput = document.getElementById('guests');
    const messageInput = document.getElementById('message');
    const checkinInput = document.getElementById('checkin');
    const checkoutInput = document.getElementById('checkout');
    const roomTypeInput = document.getElementById('roomType');
    const extras = document.querySelectorAll('.extra');
    const formStatus = document.getElementById('formStatus');

    const nameError = document.getElementById('nameError');
    const surnameError = document.getElementById('surnameError');
    const phoneError = document.getElementById('phoneError');
    const deliveryError = document.getElementById('deliveryError');
    const dateError = document.getElementById('dateError');

    const nightsCount = document.getElementById('nightsCount');
    const basePrice = document.getElementById('basePrice');
    const extrasPrice = document.getElementById('extrasPrice');
    const totalPrice = document.getElementById('totalPrice');
    const extrasList = document.getElementById('extrasList');

    if (window.emailjs) {
      window.emailjs.init({
        publicKey: EMAILJS_PUBLIC_KEY
      });
    }

    const formatDate = value => {
      if (!value) return '—';
      return new Intl.DateTimeFormat('uk-UA').format(new Date(`${value}T00:00:00`));
    };

    const getRoomOption = () => roomTypeInput.selectedOptions[0];
    const getRoomPrice = () => Number(getRoomOption().dataset.price || 0);

    const getNights = () => {
      if (!checkinInput.value || !checkoutInput.value) return 1;
      const start = new Date(checkinInput.value);
      const end = new Date(checkoutInput.value);
      const diff = Math.ceil((end - start) / (1000 * 60 * 60 * 24));
      return diff > 0 ? diff : 1;
    };

    const getSelectedExtras = () => Array.from(extras).filter(extra => extra.checked);

    const getExtrasTotal = () => {
      let sum = 0;
      extras.forEach(extra => {
        if (extra.checked) sum += Number(extra.value);
      });
      return sum;
    };

    const updateExtrasList = () => {
      const selected = getSelectedExtras();
      extrasList.innerHTML = '';

      if (!selected.length) {
        extrasList.innerHTML = '<li>Додаткових послуг ще не обрано</li>';
        return;
      }

      selected.forEach(item => {
        const li = document.createElement('li');
        li.textContent = `${item.dataset.title} (+${item.value} грн)`;
        extrasList.appendChild(li);
      });
    };

    const updateSummary = () => {
      const nights = getNights();
      const base = getRoomPrice() * nights;
      const extra = getExtrasTotal();
      const total = base + extra;

      nightsCount.textContent = String(nights);
      basePrice.textContent = `${base} грн`;
      extrasPrice.textContent = `${extra} грн`;
      totalPrice.textContent = `${total} грн`;
      updateExtrasList();
    };

    const getExtrasText = () => {
      const selectedExtras = getSelectedExtras();
      return selectedExtras.length
        ? selectedExtras.map(item => `${item.dataset.title} (+${item.value} грн)`).join(', ')
        : 'без додаткових послуг';
    };

    const getBookingSummary = () => {
      return [
        `Клієнт: ${`${nameInput.value.trim()} ${surnameInput.value.trim()}`.trim()}`,
        `Телефон: ${phoneInput.value.trim()}`,
        `Email: ${emailInput.value.trim()}`,
        `Дата заїзду: ${formatDate(checkinInput.value)}`,
        `Дата виїзду: ${formatDate(checkoutInput.value)}`,
        `Ночей: ${getNights()}`,
        `Тип будиночка: ${getRoomOption().value}`,
        `Кількість гостей: ${guestsInput.value}`,
        `Додаткові послуги: ${getExtrasText()}`,
        `Побажання: ${messageInput.value.trim() || 'без додаткових побажань'}`,
        `Разом: ${totalPrice.textContent}`
      ].join(' | ');
    };

    const getTemplateParams = () => {
      return {
        name: nameInput.value.trim(),
        surname: surnameInput.value.trim(),
        phone: phoneInput.value.trim(),
        email: emailInput.value.trim(),
        checkin: formatDate(checkinInput.value),
        checkout: formatDate(checkoutInput.value),
        guests: guestsInput.value,
        roomType: getRoomOption().value,
        selected_extras: getExtrasText(),
        nights: String(getNights()),
        total_price: totalPrice.textContent,
        message: messageInput.value.trim() || 'без додаткових побажань',
        booking_summary: getBookingSummary()
      };
    };

    const parsePriceValue = value => {
      return Number(String(value).replace(/[^\d,.-]/g, '').replace(',', '.')) || 0;
    };

    const getBookingPayload = () => {
      return {
        name: nameInput.value.trim(),
        surname: surnameInput.value.trim(),
        phone: phoneInput.value.trim(),
        email: emailInput.value.trim(),
        checkin: checkinInput.value,
        checkout: checkoutInput.value,
        guests: Number(guestsInput.value || 0),
        roomType: getRoomOption().value,
        extrasText: getExtrasText(),
        message: messageInput.value.trim(),
        nights: getNights(),
        totalPrice: parsePriceValue(totalPrice.textContent)
      };
    };

    const setFormStatus = (type, text) => {
      if (!formStatus) return;
      formStatus.className = `form-status${type ? ` ${type}` : ''}`;
      formStatus.textContent = text;
    };

    const validate = () => {
      let valid = true;
      nameError.textContent = '';
      surnameError.textContent = '';
      phoneError.textContent = '';
      deliveryError.textContent = '';
      dateError.textContent = '';

      if (nameInput.value.trim().length < 2) {
        nameError.textContent = 'Введіть ім’я щонайменше з 2 символів.';
        valid = false;
      }

      if (surnameInput.value.trim().length < 2) {
        surnameError.textContent = 'Введіть прізвище щонайменше з 2 символів.';
        valid = false;
      }

      const phoneClean = phoneInput.value.replace(/\D/g, '');
      if (phoneClean.length < 10) {
        phoneError.textContent = 'Введіть коректний номер телефону.';
        valid = false;
      }

      const emailValue = emailInput.value.trim();
      const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailPattern.test(emailValue)) {
        deliveryError.textContent = 'Введіть коректну email-адресу для підтвердження.';
        valid = false;
      }

      if (!checkinInput.value || !checkoutInput.value) {
        dateError.textContent = 'Оберіть дати заїзду та виїзду.';
        valid = false;
      } else if (new Date(checkoutInput.value) <= new Date(checkinInput.value)) {
        dateError.textContent = 'Дата виїзду має бути пізніше за дату заїзду.';
        valid = false;
      }

      return valid;
    };

    const refreshBookingState = () => {
      updateSummary();
    };

    [roomTypeInput, checkinInput, checkoutInput].forEach(el => {
      el.addEventListener('change', refreshBookingState);
    });

    extras.forEach(extra => extra.addEventListener('change', refreshBookingState));

    bookingForm.addEventListener('submit', async function (event) {
      event.preventDefault();
      refreshBookingState();

      if (!validate()) {
        setFormStatus('error', 'Форма містить помилки. Перевірте поля та спробуйте ще раз.');
        return;
      }

      const submitButton = bookingForm.querySelector('button[type="submit"]');
      if (submitButton) {
        submitButton.textContent = 'Надсилаємо...';
        submitButton.disabled = true;
      }

      setFormStatus('pending', 'Зберігаємо заявку...');

      try {
        const templateParams = getTemplateParams();
        const bookingPayload = getBookingPayload();
        const response = await fetch('/api/bookings', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(bookingPayload)
        });

        const rawResult = await response.text();
        let saveResult = null;

        try {
          saveResult = rawResult ? JSON.parse(rawResult) : null;
        } catch (parseError) {
          saveResult = null;
        }

        if (!response.ok || !saveResult || !saveResult.success) {
          let errorMessage = saveResult && saveResult.error ? saveResult.error : '';

          if (!errorMessage && rawResult) {
            const plainText = rawResult.trim();

            if (response.status === 404 && /not found/i.test(plainText)) {
              errorMessage = 'Запущено стару версію локального сервера. Закрий попереднє вікно сервера і знову відкрий start-site.bat.';
            } else {
              errorMessage = plainText;
            }
          }

          throw new Error(errorMessage || 'Database save failed.');
        }

        let emailDelivered = false;

        if (window.emailjs) {
          try {
            await window.emailjs.send(
              EMAILJS_SERVICE_ID,
              EMAILJS_TEMPLATE_ID,
              templateParams
            );

            await window.emailjs.send(
              EMAILJS_SERVICE_ID,
              EMAILJS_AUTO_REPLY_TEMPLATE_ID,
              templateParams
            );

            emailDelivered = true;
          } catch (emailError) {
            console.error('EmailJS send failed', emailError);
          }
        }

        bookingForm.reset();
        refreshBookingState();
        setFormStatus(
          'success',
          emailDelivered
            ? 'Заявку успішно збережено в базі даних та надіслано підтвердження на email.'
            : 'Заявку збережено в базі даних, але email-підтвердження не надійшло.'
        );
      } catch (error) {
        console.error('Booking submit failed', error);
        const reason = error instanceof Error && error.message ? ` Деталі: ${error.message}` : '';
        setFormStatus('error', `Не вдалося зберегти заявку.${reason}`);
      } finally {
        if (submitButton) {
          submitButton.textContent = 'Надіслати заявку';
          submitButton.disabled = false;
        }
      }
    });

    refreshBookingState();
  }
})();
