FROM ruby:3.4.2-alpine AS download

WORKDIR /fonts

RUN apk --no-cache add fontforge wget && \
    wget https://github.com/satbyy/go-noto-universal/releases/download/v7.0/GoNotoKurrent-Regular.ttf && \
    wget https://github.com/satbyy/go-noto-universal/releases/download/v7.0/GoNotoKurrent-Bold.ttf && \
    wget https://github.com/impallari/DancingScript/raw/master/fonts/DancingScript-Regular.otf && \
    wget https://cdn.jsdelivr.net/gh/notofonts/notofonts.github.io/fonts/NotoSansSymbols2/hinted/ttf/NotoSansSymbols2-Regular.ttf && \
    wget https://github.com/Maxattax97/gnu-freefont/raw/master/ttf/FreeSans.ttf && \
    wget https://github.com/impallari/DancingScript/raw/master/OFL.txt && \
    wget -O pdfium-linux.tgz "https://github.com/docusealco/pdfium-binaries/releases/latest/download/pdfium-linux-$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/').tgz" && \
    mkdir -p /pdfium-linux && \
    tar -xzf pdfium-linux.tgz -C /pdfium-linux

RUN fontforge -lang=py -c 'font1 = fontforge.open("FreeSans.ttf"); font2 = fontforge.open("NotoSansSymbols2-Regular.ttf"); font1.mergeFonts(font2); font1.generate("FreeSans.ttf")'

FROM ruby:3.4.2-alpine AS webpack

ENV RAILS_ENV=production
ENV NODE_ENV=production

WORKDIR /app

# Install node, yarn, ruby dependencies
RUN apk add --no-cache nodejs yarn git build-base sqlite-dev

# Copy Gemfiles early so bundle install layer is cached
COPY ./Gemfile ./Gemfile.lock ./

# Install bundler + gems including shakapacker
RUN gem install bundler && bundle install

# Install JS dependencies
COPY ./package.json ./yarn.lock ./
RUN yarn install --network-timeout 1000000

# Copy only the required files for asset build
COPY ./bin ./bin
COPY ./config ./config
COPY ./app/javascript ./app/javascript
COPY ./app/views ./app/views
COPY ./postcss.config.js ./postcss.config.js
COPY ./tailwind.config.js ./tailwind.config.js
COPY ./tailwind.form.config.js ./tailwind.form.config.js
COPY ./tailwind.application.config.js ./tailwind.application.config.js

# Precompile webpack assets using shakapacker
RUN bundle exec rake assets:precompile


WORKDIR /data/docuseal
ENV WORKDIR=/data/docuseal

EXPOSE 3000
CMD ["/app/bin/bundle", "exec", "puma", "-C", "/app/config/puma.rb", "--dir", "/app"]
