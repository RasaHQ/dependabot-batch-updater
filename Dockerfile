FROM dependabot/dependabot-core
ARG CODE_DIR=/dist
WORKDIR ${CODE_DIR}

COPY Gemfile ${CODE_DIR}/
COPY Gemfile.lock ${CODE_DIR}/

RUN bundle install

# install dependencies
ENV PATH="/usr/local/.pyenv/bin:/usr/local/.pyenv/versions/3.8.5/bin:$PATH"
RUN pyenv install 3.8.5
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
RUN python get-pip.py
RUN pip install poetry==1.0.9

# copy scripts
COPY update_script.rb ${CODE_DIR}/
COPY src/ ${CODE_DIR}/src/

# run script
ENTRYPOINT ["ruby", "/dist/update_script.rb"]